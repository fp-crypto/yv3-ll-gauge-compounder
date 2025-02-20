// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {dYFIHelper} from "./libraries/dYFIHelper.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IGauge} from "./interfaces/veyfi/IGauge.sol";

import {Base4626Compounder, ERC20, IStrategy} from "@periphery/Bases/4626Compounder/Base4626Compounder.sol";
import {UniswapV3Swapper} from "@periphery/swappers/UniswapV3Swapper.sol";

/// @title Base Liquid Locker Gauge Compounder Strategy
/// @notice Abstract base contract for Liquid Locker gauge compounding strategies
/// @dev Inherits Base4626Compounder for vault functionality, and includes UniswapV3 and Auction swapping capabilities
/// @custom:security-contact security@yearn.fi
abstract contract BaseLLGaugeCompounderStrategy is
    Base4626Compounder,
    UniswapV3Swapper
{
    /// @notice The Wrapped Ether contract address
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @notice Flag to disable automatic conversion of dYFI rewards to WETH
    /// @dev When true, dYFI rewards will remain in the contract
    bool public dontDumpDYfi;

    /// @notice Flag to disable automatic swapping of WETH to the strategy's asset
    /// @dev When true, WETH will remain in the contract
    bool public dontSwapWeth;

    /// @notice Flag to enable using auctions for token swaps
    /// @dev When true, uses auction-based swapping mechanism instead of Uniswap
    bool public useAuctions;

    IGauge public immutable Y_GAUGE;

    /// @notice Initializes the strategy with vault parameters and Uniswap settings
    /// @param _yGauge Address of the yearn gauge
    /// @param _name Name of the strategy token
    /// @param _assetSwapUniFee Uniswap V3 fee tier for asset swaps (use 0 if asset is WETH)
    /// @dev Sets up Uniswap fee tiers for non-WETH assets
    constructor(
        address _yGauge,
        string memory _name,
        uint24 _assetSwapUniFee
    )
        Base4626Compounder(
            IStrategy(IStrategy(_yGauge).asset()).asset(), // the underlying asset
            _name,
            IStrategy(_yGauge).asset() // the vault
        )
    {
        Y_GAUGE = IGauge(_yGauge);
        minAmountToSell = 0.005e18; // minEthToSwap;
        if (address(asset) != WETH && _assetSwapUniFee != 0) {
            _setUniFees(WETH, address(asset), _assetSwapUniFee);
        } else {
            dontSwapWeth = true;
        }
    }

    /// @notice Claims dYFI rewards and optionally converts them to the strategy's asset
    /// @dev Override of Base4626Compounder._claimAndSellRewards()
    /// @dev First claims dYFI, then optionally converts to WETH, then optionally swaps WETH to asset
    function _claimAndSellRewards() internal override {
        _claimDYfi();

        if (!dontDumpDYfi) {
            dYFIHelper.dumpToWeth();
        }

        if (
            !dontSwapWeth &&
            address(asset) != address(WETH) &&
            uniFees[address(WETH)][address(asset)] != 0
        ) {
            _swapFrom(
                address(WETH),
                address(asset),
                ERC20(WETH).balanceOf(address(this)),
                0
            );
        }
    }

    /// @notice Claims dYFI rewards from the gauge
    /// @dev Must be implemented by derived contracts to handle specific gauge claiming logic
    function _claimDYfi() internal virtual;

    /// @notice Callback function for Balancer flash loans
    /// @dev Called by Balancer Vault during flash loan execution
    /// @param tokens Array of token addresses for the flash loan
    /// @param amounts Array of amounts for each token
    /// @param feeAmounts Array of fee amounts for each token
    /// @param userData Additional data passed through the flash loan
    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        require(msg.sender == address(dYFIHelper.BALANCER_VAULT), "!balancer");
        require(feeAmounts.length == 1 && feeAmounts[0] == 0, "fee");
        dYFIHelper.flashloanLogic(userData);
    }

    /// @notice Sets whether to disable automatic conversion of dYFI rewards to WETH
    /// @param _dontDumpDYfi New value for dontDumpDYfi flag
    /// @dev Can only be called by governance
    function setDontDumpDYfi(bool _dontDumpDYfi) external onlyManagement {
        dontDumpDYfi = _dontDumpDYfi;
    }

    /// @notice Sets whether to disable automatic swapping of WETH to strategy asset
    /// @param _dontSwapWeth New value for dontSwapWeth flag
    /// @dev Can only be called by governance
    function setDontSwapWeth(bool _dontSwapWeth) external onlyManagement {
        dontSwapWeth = _dontSwapWeth;
    }

    /// @notice Sets whether to use auctions for token swaps
    /// @param _useAuctions New value for useAuctions flag
    /// @dev Can only be called by governance
    function setUseAuctions(bool _useAuctions) external onlyManagement {
        useAuctions = _useAuctions;
    }

    /// @notice Sets the Uniswap V3 fee tier for WETH to asset swaps
    /// @dev Can only be called by management
    /// @param _wethToAssetSwapFee The fee tier to use (in hundredths of a bip)
    function setWethToAssetSwapFee(
        uint24 _wethToAssetSwapFee
    ) external onlyManagement {
        _setUniFees(WETH, address(asset), _wethToAssetSwapFee);
    }

    /// @notice Sets the minimum amount of WETH required to trigger a swap
    /// @dev Can only be called by management
    /// @param _minWethToSwap Minimum amount of WETH tokens (in wei) needed to execute a swap
    function setMinWethToSwap(uint256 _minWethToSwap) external onlyManagement {
        minAmountToSell = _minWethToSwap;
    }

    /// @notice Allows the contract to receive ETH
    /// @dev Required for WETH unwrapping
    receive() external payable {}
}
