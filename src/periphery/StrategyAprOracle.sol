// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {AprOracle} from "@periphery/AprOracle/AprOracle.sol";
import {AprOracleBase} from "@periphery/AprOracle/AprOracleBase.sol";
import {IBaseLLGaugeCompounderStrategy} from "../interfaces/IBaseLLGaugeCompounderStrategy.sol";
import {ICurvePool} from "../interfaces/ICurvePool.sol";
import {IDYFIRedeemer} from "../interfaces/IDYFIRedeemer.sol";
import {IGauge} from "../interfaces/veyfi/IGauge.sol";
import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {UniswapV3SwapSimulator, ISwapRouter} from "../libraries/UniswapV3SwapSimulator.sol";
import {AggregatorV3Interface} from "../interfaces/chainlink/AggregatorV3Interface.sol";

contract StrategyAprOracle is AprOracleBase {
    /// @notice Curve pool for dYFI/ETH swaps
    ICurvePool public constant CURVE_DYFI_ETH =
        ICurvePool(0x8aC64Ba8E440cE5c2d08688f4020698b1826152E);
    /// @notice Curve pool for YFI/ETH swaps
    ICurvePool public constant CURVE_YFI_ETH =
        ICurvePool(0xC26b89A667578ec7b3f11b2F98d6Fd15C07C54ba);
    /// @notice dYFI Redeemer contract for converting dYFI to YFI
    IDYFIRedeemer public constant DYFI_REDEEMER =
        IDYFIRedeemer(0x7dC3A74F0684fc026f9163C6D5c3C99fda2cf60a);
    /// @notice The Uniswap V3 Router contract address used for swap simulations
    address private constant UNISWAP_V3_ROUTER =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;
    /// @notice The Wrapped Ether contract address
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant veYFI = 0x90c1f9220d90d3966FbeE24045EDd73E1d588aD5;

    // Mapping to store performance fees for different liquid locker types
    // Fees are expressed as percentage * 1e18 (e.g., 15% = 15 * 1e16)
    mapping(bytes32 => uint256) public performanceFeeByType;

    mapping(address => bool) public isStable;

    address public ethUsdChainlinkFeed =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    address public aprOracle = 0x1981AD9F44F2EA9aDd2dC4AD7D075c102C70aF92;

    constructor(
        address _governance
    ) AprOracleBase("yv^2 apr oracle", _governance) {
        // Initialize default performance fees for known locker types
        performanceFeeByType[keccak256(bytes("Cove"))] = 15 * 1e16; // 15% default
        performanceFeeByType[keccak256(bytes("StakeDao"))] = 15 * 1e16; // 15% default
        performanceFeeByType[keccak256(bytes("1up"))] = 10 * 1e16; // 10% default (max fee)
    }

    /**
     * @notice Returns the expected Apr of a strategy post a debt change.
     * @param _strategy The token to get the apr for.
     * @param _delta The difference in debt.
     * @return _apr The expected apr for the strategy represented as 1e18.
     */
    function aprAfterDebtChange(
        address _strategy,
        int256 _delta
    ) external view override returns (uint256 _apr) {
        _apr = baseApr(_strategy, _delta);
        _apr += dyfiApr(_strategy, _delta);
    }

    function baseApr(
        address _strategy,
        int256 _delta
    ) public view returns (uint256 _apr) {
        _apr = AprOracle(aprOracle).getStrategyApr(
            IBaseLLGaugeCompounderStrategy(_strategy).vault(),
            _delta
        );
    }

    function dyfiApr(
        address _strategy,
        int256 _delta
    ) public view returns (uint256 _apr) {
        address strategyAsset = address(
            IBaseLLGaugeCompounderStrategy(_strategy).asset()
        );

        // Get total assets of strategy (accounting for potential delta)
        uint256 totalAssets = IBaseLLGaugeCompounderStrategy(_strategy)
            .totalAssets();

        if (_delta >= int256(totalAssets)) return 0;

        if (_delta > 0) {
            totalAssets += uint256(_delta);
        } else if (_delta < 0) {
            totalAssets -= uint256(-_delta);
        }

        address vault = IBaseLLGaugeCompounderStrategy(_strategy).vault();
        address gauge = IBaseLLGaugeCompounderStrategy(_strategy).Y_GAUGE();
        address gauge_holder = IBaseLLGaugeCompounderStrategy(_strategy)
            .Y_GAUGE_SHARE_HOLDER();
        int256 _shareDelta = _delta >= 0
            ? int256(IERC4626(vault).convertToShares(uint256(_delta)))
            : -int256(IERC4626(vault).convertToShares(uint256(-_delta)));
        // Get current gauge balances and total supplies
        uint256 gaugeBalance = IERC20(gauge).balanceOf(gauge_holder);
        uint256 gaugeTotalSupply = IERC20(gauge).totalSupply();

        // Calculate adjusted values with delta
        uint256 adjustedGaugeBalance = uint256(
            int256(gaugeBalance) + _shareDelta
        );
        uint256 adjustedGaugeTotalSupply = uint256(
            int256(gaugeTotalSupply) + _shareDelta
        );

        // Calculate the boosted balance (this is what determines reward share)
        uint256 boostedBalance = calculateBoostFromDeposit(
            IERC20(veYFI).balanceOf(gauge_holder),
            IERC20(veYFI).totalSupply(),
            adjustedGaugeBalance,
            adjustedGaugeTotalSupply
        );

        // Get global reward rate from gauge (total dYFI emissions per second)
        uint256 globalRewardRate = IGauge(gauge).rewardRate();

        // Calculate our proportional share of rewards based on boosted balance
        uint256 userRewardRate = 0;
        if (adjustedGaugeTotalSupply > 0) {
            userRewardRate =
                (globalRewardRate * boostedBalance) /
                adjustedGaugeTotalSupply;
        }

        // Calculate rewards per week based on our share
        uint256 weeklyRewards = (userRewardRate * 7 days) / 1e18;

        // Convert weekly dYFI rewards to WETH
        uint256 weeklyWethValue = dyfiToWeth(weeklyRewards);

        // Annualize the weekly rewards
        uint256 annualWethValue = (weeklyWethValue * 365 days) / 7 days;

        // Apply the appropriate performance fee based on strategy type
        uint256 performanceFee = getPerformanceFee(_strategy);
        if (performanceFee > 0) {
            // Reduce the APR by the performance fee percentage
            annualWethValue =
                (annualWethValue * (1e18 - performanceFee)) /
                1e18;
        }

        if (strategyAsset == WETH) {
            _apr = (annualWethValue * 1e18) / totalAssets;
            return _apr;
        }
        // Get the swap fee for WETH -> asset from the strategy
        uint24 wethAssetFee = IBaseLLGaugeCompounderStrategy(_strategy).uniFees(
            WETH,
            strategyAsset
        );

        // If we have a valid fee tier, convert WETH to asset using Uniswap simulation
        if (wethAssetFee != 0) {
            // Convert WETH value to asset value using Uniswap simulation
            uint256 annualAssetValue = wethInAsset(
                annualWethValue,
                strategyAsset,
                wethAssetFee
            );

            // Calculate APR using the asset value
            _apr =
                (annualAssetValue * 10 ** IERC20(strategyAsset).decimals()) /
                totalAssets;
        } else if (isStable[strategyAsset]) {
            // Get ETH price in USD from Chainlink
            (, int256 price, , , ) = AggregatorV3Interface(ethUsdChainlinkFeed)
                .latestRoundData();
            require(price > 0, "Invalid ETH price");

            // Convert the WETH value to USD (Chainlink uses 8 decimals for price)
            // and then to the stable asset equivalent
            uint256 stableDecimals = IERC20(strategyAsset).decimals();
            uint256 annualStableValue = (annualWethValue *
                uint256(price) *
                (10 ** stableDecimals)) /
                (10 **
                    (18 +
                        uint256(
                            AggregatorV3Interface(ethUsdChainlinkFeed)
                                .decimals()
                        ))); // Adjust for WETH (18) + Chainlink (8) decimals

            _apr = (annualStableValue * 1e18) / totalAssets;
        } else {
            // No valid fee and not a stablecoin - this is an error case
            revert("No valid conversion path");
        }
    }

    function dyfiToWeth(uint256 _dyfiAmount) public view returns (uint256) {
        if (_dyfiAmount == 0) return 0;

        uint256 amountOutSwap = CURVE_DYFI_ETH.get_dy(0, 1, _dyfiAmount);

        uint256 ethRequired = DYFI_REDEEMER.eth_required(_dyfiAmount);
        uint256 amountOutYfiEth = CURVE_YFI_ETH.get_dy(1, 0, _dyfiAmount);
        uint256 amountOutRedeem;
        if (amountOutYfiEth > ethRequired) {
            amountOutRedeem = amountOutYfiEth - ethRequired;
        }

        return
            (amountOutRedeem > amountOutSwap) ? amountOutRedeem : amountOutSwap;
    }

    function setIsStable(
        address _asset,
        bool _isStable
    ) external onlyGovernance {
        isStable[_asset] = _isStable;
    }

    /**
     * @notice Set the performance fee for a specific locker type
     * @param _lockerType The string identifier for the locker type (e.g., "Cove", "StakeDao", "1up")
     * @param _fee The new fee percentage (1e18 = 100%)
     * @dev Can only be called by governance
     */
    function setPerformanceFee(string memory _lockerType, uint256 _fee) external onlyGovernance {
        require(_fee <= 50 * 1e16, "Fee too high"); // Cap at 50%
        bytes32 lockerTypeHash = keccak256(bytes(_lockerType));
        performanceFeeByType[lockerTypeHash] = _fee;
    }

    /**
     * @notice Determine the appropriate performance fee based on strategy type
     * @param _strategy The strategy address
     * @return fee The performance fee percentage (1e18 = 100%)
     */
    function getPerformanceFee(
        address _strategy
    ) public view returns (uint256 fee) {
        // Get strategy type hash from the strategy contract
        bytes32 lockerTypeHash = IBaseLLGaugeCompounderStrategy(_strategy)
            .LOCKER_TYPE_HASH();
            
        // Get fee from mapping, returns 0 if not set
        return performanceFeeByType[lockerTypeHash];
    }

    /**
     * @notice Calculates the boosted balance for a deposit based on veYFI holdings
     * @dev This recreates the gauge's _boostedBalanceOf logic to predict boost after a deposit change
     * @param _veYFIAmount The amount of veYFI held by the gauge holder
     * @param _veYfiTotalSupply The total supply of veYFI
     * @param _gaugeAmount The gauge token balance (adjusted by delta if calculating for a change)
     * @param _gaugeTotalSupply The total supply of gauge tokens (adjusted by delta if calculating for a change)
     * @return The boosted balance, which determines the share of rewards
     */
    function calculateBoostFromDeposit(
        uint256 _veYFIAmount,
        uint256 _veYfiTotalSupply,
        uint256 _gaugeAmount,
        uint256 _gaugeTotalSupply
    ) public pure returns (uint256) {
        // If no veYFI in the system, no boost is possible
        if (_veYfiTotalSupply == 0) {
            return _gaugeAmount;
        }

        // These values match the gauge contract constants
        uint256 BOOSTING_FACTOR = 1;
        uint256 BOOST_DENOMINATOR = 10;

        // Calculate boosted balance using the same formula as the gauge contract:
        // min(
        //   ((realBalance * BOOSTING_FACTOR) +
        //    ((totalSupply * veYFIBalance) / veYFITotalSupply) *
        //    (BOOST_DENOMINATOR - BOOSTING_FACTOR)) / BOOST_DENOMINATOR,
        //   realBalance
        // )
        uint256 boostedBalance = ((_gaugeAmount * BOOSTING_FACTOR) +
            ((_gaugeTotalSupply * _veYFIAmount) / _veYfiTotalSupply) *
            (BOOST_DENOMINATOR - BOOSTING_FACTOR)) / BOOST_DENOMINATOR;

        // Ensure boosted balance never exceeds real balance
        return Math.min(boostedBalance, _gaugeAmount);
    }

    function wethInAsset(
        uint256 _wethAmount,
        address _asset,
        uint24 _wethAssetFee
    ) private view returns (uint256 _assetAmount) {
        if (_wethAmount == 0) {
            return 0;
        }

        _assetAmount = UniswapV3SwapSimulator.simulateExactInputSingle(
            ISwapRouter(UNISWAP_V3_ROUTER),
            ISwapRouter.ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: _asset,
                fee: _wethAssetFee,
                recipient: address(0),
                deadline: block.timestamp,
                amountIn: _wethAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }
}
