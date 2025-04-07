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

/**
 * @title StrategyAprOracle
 * @notice Oracle for calculating APR for liquid locker gauge compounder strategies.
 * @dev This contract provides APR calculations that account for:
 *      1. Base APR from underlying assets
 *      2. dYFI rewards from YFI gauges, with veYFI boosting
 *      3. Liquid locker performance fees
 *      4. Token price conversion via Curve, Uniswap, or Chainlink
 */
contract StrategyAprOracle is AprOracleBase {
    /*//////////////////////////////////////////////////////////////
                           GLOBAL CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Standard scaling factor for calculations (10^18)
    uint256 private constant WAD = 1e18;

    /*//////////////////////////////////////////////////////////////
                            TOKEN CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The Wrapped Ether contract address
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @notice The veYFI token address - used for boost calculations
    address public constant veYFI = 0x90c1f9220d90d3966FbeE24045EDd73E1d588aD5;

    /*//////////////////////////////////////////////////////////////
                        PROTOCOL CONTRACTS
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                          STORAGE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping to identify stablecoin tokens for price conversion
    /// @dev For stablecoins, we use Chainlink ETH/USD for conversion
    mapping(address => bool) public isStable;

    /// @notice Mapping to store performance fees for different liquid locker types
    /// @dev Fees are expressed as percentage * 1e18 (e.g., 15% = 15 * 1e16)
    mapping(bytes32 => uint256) public performanceFeeByType;

    /// @notice Chainlink ETH/USD price feed address
    address public ethUsdChainlinkFeed =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    /// @notice Base APR oracle address
    address public aprOracle = 0x1981AD9F44F2EA9aDd2dC4AD7D075c102C70aF92;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _governance
    ) AprOracleBase("yv^2 apr oracle", _governance) {
        // Initialize default performance fees for known locker types
        performanceFeeByType[keccak256(bytes("Cove"))] = (15 * WAD) / 100; // 15% default
        performanceFeeByType[keccak256(bytes("StakeDao"))] = (15 * WAD) / 100; // 15% default
        performanceFeeByType[keccak256(bytes("1up"))] = (10 * WAD) / 100; // 10% default (max fee)
    }

    /*//////////////////////////////////////////////////////////////
                         APR CALCULATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    /**
     * @notice Calculates the base APR for a strategy from the underlying vault
     * @param _strategy Address of the strategy
     * @param _delta Change in debt amount
     * @return _apr The base APR in 1e18 scale
     */
    function baseApr(
        address _strategy,
        int256 _delta
    ) public view returns (uint256 _apr) {
        _apr = AprOracle(aprOracle).getStrategyApr(
            IBaseLLGaugeCompounderStrategy(_strategy).vault(),
            _delta
        );
    }

    /**
     * @notice Calculates the APR contribution from dYFI rewards
     * @param _strategy Address of the strategy
     * @param _delta Change in debt amount
     * @return _apr The dYFI reward APR in 1e18 scale
     */
    function dyfiApr(
        address _strategy,
        int256 _delta
    ) public view returns (uint256 _apr) {
        // Get strategy asset and total assets (adjusted for delta)
        address strategyAsset = address(
            IBaseLLGaugeCompounderStrategy(_strategy).asset()
        );
        uint256 totalAssets = calculateAdjustedTotalAssets(_strategy, _delta);

        // Exit early if all assets would be withdrawn
        if (totalAssets == 0) return 0;

        // Calculate weekly rewards based on gauge balances and boost
        uint256 weeklyRewards = calculateWeeklyRewards(
            _strategy,
            _delta,
            totalAssets
        );

        // Convert weekly dYFI rewards to WETH value
        uint256 weeklyWethValue = dyfiToWeth(weeklyRewards);

        // Annualize the weekly rewards
        uint256 annualWethValue = (weeklyWethValue * 365 days) / 7 days;

        // Apply the appropriate performance fee based on strategy type
        annualWethValue = applyPerformanceFee(annualWethValue, _strategy);

        // Convert annual WETH value to APR based on asset type
        _apr = calculateApr(
            annualWethValue,
            totalAssets,
            strategyAsset,
            _strategy
        );
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS FOR dyfiApr
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the adjusted total assets accounting for debt change
     * @param _strategy Address of the strategy
     * @param _delta Change in debt amount
     * @return _totalAssets The adjusted total assets amount
     */
    function calculateAdjustedTotalAssets(
        address _strategy,
        int256 _delta
    ) internal view returns (uint256 _totalAssets) {
        _totalAssets = IBaseLLGaugeCompounderStrategy(_strategy).totalAssets();

        if (-_delta >= int256(_totalAssets)) return 0;

        if (_delta > 0) {
            _totalAssets += uint256(_delta);
        } else if (_delta < 0) {
            _totalAssets -= uint256(-_delta);
        }
    }

    /**
     * @notice Calculates weekly dYFI rewards based on gauge balances and boost
     * @param _strategy Address of the strategy
     * @param _delta Change in debt amount
     * @return Weekly dYFI rewards amount
     */
    function calculateWeeklyRewards(
        address _strategy,
        int256 _delta,
        uint256 _totalAssets
    ) internal view returns (uint256) {
        // Get strategy contracts and state
        address vault = IBaseLLGaugeCompounderStrategy(_strategy).vault();
        address gauge = IBaseLLGaugeCompounderStrategy(_strategy).Y_GAUGE();
        address gaugeHolder = IBaseLLGaugeCompounderStrategy(_strategy)
            .Y_GAUGE_SHARE_HOLDER();

        // Convert asset delta to share delta if needed
        int256 _shareDelta = _delta >= 0
            ? int256(IERC4626(vault).convertToShares(uint256(_delta)))
            : -int256(IERC4626(vault).convertToShares(uint256(-_delta)));

        // Get current gauge balances and total supplies
        uint256 gaugeBalance = IERC20(gauge).balanceOf(gaugeHolder);
        uint256 gaugeTotalSupply = IERC20(gauge).totalSupply();

        uint256 adjustedGaugeBalance = uint256(
            int256(gaugeBalance) + _shareDelta
        );
        uint256 adjustedGaugeTotalSupply = uint256(
            int256(gaugeTotalSupply) + _shareDelta
        );

        // Calculate the boost factor from the gauge holder's perspective
        uint256 boostFactor = calculateBoostFactorFromDeposit(
            IERC20(veYFI).balanceOf(gaugeHolder),
            IERC20(veYFI).totalSupply(),
            adjustedGaugeBalance,
            adjustedGaugeTotalSupply
        );

        // Apply boost factor to strategy balance to get boosted balance
        uint256 boostedBalance = (_totalAssets * boostFactor) / WAD;

        // Get global reward rate and calculate user's share
        uint256 globalRewardRate = IGauge(gauge).rewardRate();
        uint256 userRewardRate = 0;
        if (adjustedGaugeTotalSupply > 0) {
            userRewardRate =
                (globalRewardRate * boostedBalance) /
                adjustedGaugeTotalSupply;
        }

        // Calculate rewards per week based on our share
        // Note: globalRewardRate includes PRECISION_FACTOR (WAD), so divide by WAD
        return (userRewardRate * 7 days) / WAD;
    }

    /**
     * @notice Applies performance fee to the annual WETH value
     * @param _annualWethValue Annual WETH value before fee
     * @param _strategy Address of the strategy
     * @return Annual WETH value after performance fee
     */
    function applyPerformanceFee(
        uint256 _annualWethValue,
        address _strategy
    ) internal view returns (uint256) {
        uint256 performanceFee = getPerformanceFee(_strategy);
        if (performanceFee > 0) {
            // Reduce the APR by the performance fee percentage
            return (_annualWethValue * (WAD - performanceFee)) / WAD;
        }
        return _annualWethValue;
    }

    /**
     * @notice Calculates APR from annual WETH value based on strategy asset type
     * @param _annualWethValue Annual WETH value
     * @param _totalAssets Total strategy assets (adjusted for delta)
     * @param _strategyAsset Strategy asset address
     * @param _strategy Strategy address
     * @return APR value in 1e18 scale
     */
    function calculateApr(
        uint256 _annualWethValue,
        uint256 _totalAssets,
        address _strategyAsset,
        address _strategy
    ) internal view returns (uint256) {
        // If strategy asset is WETH, direct calculation
        if (_strategyAsset == WETH) {
            return (_annualWethValue * WAD) / _totalAssets;
        }

        // Get the swap fee for WETH -> asset from the strategy
        uint24 wethAssetFee = IBaseLLGaugeCompounderStrategy(_strategy).uniFees(
            WETH,
            _strategyAsset
        );

        // If we have a valid fee tier, convert WETH to asset using Uniswap simulation
        if (wethAssetFee != 0) {
            // Convert WETH value to asset value using Uniswap simulation
            uint256 annualAssetValue = wethInAsset(
                _annualWethValue / 52,
                _strategyAsset,
                wethAssetFee
            ) * 52;

            // Calculate APR using the asset value
            return
                (annualAssetValue * 10 ** IERC20(_strategyAsset).decimals()) /
                _totalAssets;
        }
        // For stablecoins, use Chainlink ETH/USD oracle
        else if (isStable[_strategyAsset]) {
            return
                calculateStablecoinApr(
                    _annualWethValue,
                    _totalAssets,
                    _strategyAsset
                );
        }
        // No valid conversion path - this is an error case
        else {
            revert("no path");
        }
    }

    /**
     * @notice Calculates APR for stablecoin assets using Chainlink oracle
     * @param _annualWethValue Annual WETH value
     * @param _totalAssets Total strategy assets
     * @param _strategyAsset Strategy asset address (should be a stablecoin)
     * @return APR value in 1e18 scale
     */
    function calculateStablecoinApr(
        uint256 _annualWethValue,
        uint256 _totalAssets,
        address _strategyAsset
    ) internal view returns (uint256) {
        // Get ETH price in USD from Chainlink
        (, int256 price, , , ) = AggregatorV3Interface(ethUsdChainlinkFeed)
            .latestRoundData();
        require(price > 0, "Invalid ETH price");

        uint256 oracleDecimals = AggregatorV3Interface(ethUsdChainlinkFeed)
            .decimals();

        // Convert the WETH value to USD using Chainlink price
        uint256 stableDecimals = IERC20(_strategyAsset).decimals();
        uint256 annualStableValue = (_annualWethValue * uint256(price)) /
            (10 ** oracleDecimals);

        // Calculate APR formula components
        uint256 scalingFactor = 10 ** (18 - stableDecimals);
        uint256 scaledTotalAssets = _totalAssets * scalingFactor;

        return (annualStableValue * WAD) / scaledTotalAssets;
    }

    /*//////////////////////////////////////////////////////////////
                       TOKEN CONVERSION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Converts dYFI amount to WETH using the best available path
     * @param _dyfiAmount Amount of dYFI to convert
     * @return WETH amount after conversion
     */
    function dyfiToWeth(uint256 _dyfiAmount) public view returns (uint256) {
        if (_dyfiAmount == 0) return 0;

        // Path 1: Direct swap via Curve dYFI/ETH pool
        uint256 amountOutSwap = CURVE_DYFI_ETH.get_dy(0, 1, _dyfiAmount);

        // Path 2: Redeem dYFI for YFI and then swap YFI for ETH
        uint256 ethRequired = DYFI_REDEEMER.eth_required(_dyfiAmount);
        uint256 amountOutYfiEth = CURVE_YFI_ETH.get_dy(1, 0, _dyfiAmount);
        uint256 amountOutRedeem;
        if (amountOutYfiEth > ethRequired) {
            amountOutRedeem = amountOutYfiEth - ethRequired;
        }

        // Return the better of the two paths
        return
            (amountOutRedeem > amountOutSwap) ? amountOutRedeem : amountOutSwap;
    }

    /**
     * @notice Simulates a Uniswap V3 swap from WETH to a target asset
     * @param _wethAmount Amount of WETH to swap
     * @param _asset Target asset address
     * @param _wethAssetFee Uniswap fee tier for the pair
     * @return _assetAmount Target asset amount after swap
     */
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

    /*//////////////////////////////////////////////////////////////
                             GAUGE BOOST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the boost factor based on veYFI holdings
     * @dev This recreates the gauge's boost calculation logic to predict boost after a deposit change
     * @param _veYFIAmount The amount of veYFI held by the gauge holder
     * @param _veYfiTotalSupply The total supply of veYFI
     * @param _gaugeAmount The gauge token balance (adjusted by delta if calculating for a change)
     * @param _gaugeTotalSupply The total supply of gauge tokens (adjusted by delta if calculating for a change)
     * @return The boost factor as a WAD percentage (1e18 = 100% = no boost)
     */
    function calculateBoostFactorFromDeposit(
        uint256 _veYFIAmount,
        uint256 _veYfiTotalSupply,
        uint256 _gaugeAmount,
        uint256 _gaugeTotalSupply
    ) public pure returns (uint256) {
        // If no veYFI in the system or no gauge balance, no boost is possible
        if (_veYfiTotalSupply == 0 || _gaugeAmount == 0) {
            return WAD;
        }

        // These values match the gauge contract constants
        uint256 BOOSTING_FACTOR = 1;
        uint256 BOOST_DENOMINATOR = 10;

        // First component: gaugeAmount * BOOSTING_FACTOR
        uint256 component1 = _gaugeAmount * BOOSTING_FACTOR;

        // Second component: (gaugeTotalSupply * veYFIAmount) / veYFITotalSupply
        uint256 component2 = (_gaugeTotalSupply * _veYFIAmount) /
            _veYfiTotalSupply;

        // Multiply component 2 by (BOOST_DENOMINATOR - BOOSTING_FACTOR)
        uint256 component3 = component2 * (BOOST_DENOMINATOR - BOOSTING_FACTOR);

        // Calculate boosted balance using the same formula as the gauge contract:
        // min(
        //   ((realBalance * BOOSTING_FACTOR) +
        //    ((totalSupply * veYFIBalance) / veYFITotalSupply) *
        //    (BOOST_DENOMINATOR - BOOSTING_FACTOR)) / BOOST_DENOMINATOR,
        //   realBalance
        // )
        uint256 boostedBalance = (component1 + component3) / BOOST_DENOMINATOR;

        // Ensure boosted balance never exceeds real balance
        boostedBalance = Math.min(boostedBalance, _gaugeAmount);

        // Calculate and return the boost factor (as WAD percentage)
        return (boostedBalance * WAD) / _gaugeAmount;
    }

    /*//////////////////////////////////////////////////////////////
                       PERFORMANCE FEE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Determine the appropriate performance fee based on strategy type
     * @param _strategy The strategy address
     * @return fee The performance fee percentage (WAD = 100%)
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

    /*//////////////////////////////////////////////////////////////
                         GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the performance fee for a specific locker type
     * @param _lockerType The string identifier for the locker type (e.g., "Cove", "StakeDao", "1up")
     * @param _fee The new fee percentage (WAD = 100%)
     * @dev Can only be called by governance
     */
    function setPerformanceFee(
        string memory _lockerType,
        uint256 _fee
    ) external onlyGovernance {
        require(_fee <= (50 * WAD) / 100, "Fee too high"); // Cap at 50%
        bytes32 lockerTypeHash = keccak256(bytes(_lockerType));
        performanceFeeByType[lockerTypeHash] = _fee;
    }

    /**
     * @notice Mark an asset as a stablecoin for price conversion
     * @param _asset The asset address
     * @param _isStable Whether the asset is a stablecoin
     * @dev Can only be called by governance
     */
    function setIsStable(
        address _asset,
        bool _isStable
    ) external onlyGovernance {
        isStable[_asset] = _isStable;
    }
}
