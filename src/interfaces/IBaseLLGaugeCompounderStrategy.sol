// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IBase4626Compounder} from "@periphery/Bases/4626Compounder/IBase4626Compounder.sol";
import {IUniswapV3Swapper} from "@periphery/swappers/interfaces/IUniswapV3Swapper.sol";

/// @title IBaseLLGaugeCompounderStrategy
/// @notice Interface for the Base Liquid Locker Gauge Compounder Strategy
/// @dev Extends IStrategyInterface with LL gauge specific functionality
interface IBaseLLGaugeCompounderStrategy is
    IBase4626Compounder,
    IUniswapV3Swapper
{
    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    function Y_GAUGE() external view returns (address);

    /// @notice The parent allocator vault that distributes funds between LL strategies
    /// @dev This vault is responsible for allocating assets between different LL providers
    function PARENT_VAULT() external view returns (address);

    /// @notice The Wrapped Ether contract address
    function WETH() external view returns (address);

    /// @notice Flag indicating if automatic conversion of dYFI rewards to WETH is disabled
    function dontDumpDYfi() external view returns (bool);

    /// @notice Flag indicating if automatic swapping of WETH to strategy asset is disabled
    function dontSwapWeth() external view returns (bool);

    /// @notice Flag indicating if auctions should be used for token swaps
    function useAuctions() external view returns (bool);

    /// @notice Flag to control whether deposits are open to all addresses or restricted to the parent vault
    /// @dev When true, any address can deposit; when false, only the parent vault can deposit
    function openDeposits() external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                            MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Callback function for Balancer flash loans
    /// @param tokens Array of token addresses for the flash loan
    /// @param amounts Array of amounts for each token
    /// @param feeAmounts Array of fee amounts for each token
    /// @param userData Additional data passed through the flash loan
    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external;

    /*//////////////////////////////////////////////////////////////
                         MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets whether to disable automatic conversion of dYFI rewards to WETH
    /// @param _dontDumpDYfi New value for dontDumpDYfi flag
    function setDontDumpDYfi(bool _dontDumpDYfi) external;

    /// @notice Sets whether to disable automatic swapping of WETH to strategy asset
    /// @param _dontSwapWeth New value for dontSwapWeth flag
    function setDontSwapWeth(bool _dontSwapWeth) external;

    /// @notice Sets whether to use auctions for token swaps
    /// @param _useAuctions New value for useAuctions flag
    function setUseAuctions(bool _useAuctions) external;

    /// @notice Sets whether deposits are open to all addresses or restricted to the parent vault
    /// @param _openDeposits When true, any address can deposit; when false, only the parent vault can deposit
    /// @dev Used to control deposit access during different operational phases or market conditions
    function setOpenDeposits(bool _openDeposits) external;

    /// @notice Sets the Uniswap V3 fee tier for WETH to asset swaps
    /// @param _wethToAssetSwapFee The fee tier to use (in hundredths of a bip)
    function setWethToAssetSwapFee(uint24 _wethToAssetSwapFee) external;

    /// @notice Sets the minimum amount of WETH required to trigger a swap
    /// @param _minWethToSwap Minimum amount of WETH tokens (in wei) needed to execute a swap
    function setMinWethToSwap(uint256 _minWethToSwap) external;

    /// @notice Sets the auction contract address
    /// @param _auction Address of the auction contract
    /// @dev Can only be called by management
    /// @dev Verifies the auction contract is compatible with this strategy
    function setAuction(address _auction) external;

    /// @notice Initiates an auction for a given token
    /// @dev Can only be called by keepers when auctions are enabled
    /// @param _from The token to be sold in the auction
    /// @return . The available amount for bidding on in the auction.
    function kickAuction(address _from) external returns (uint256);
}
