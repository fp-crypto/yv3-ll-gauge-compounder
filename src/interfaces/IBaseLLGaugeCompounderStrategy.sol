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
    
    /// @notice The dYFI token contract address
    function DYFI() external view returns (address);

    /// @notice Flag indicating if dYFI rewards should be kept instead of converting to WETH
    function keepDYfi() external view returns (bool);

    /// @notice Flag indicating if WETH should be kept instead of swapping to strategy asset
    function keepWeth() external view returns (bool);

    /// @notice Flag indicating if auctions should be used for token swaps
    function useAuctions() external view returns (bool);
    
    /// @notice Address of the auction contract used for token swaps
    function auction() external view returns (address);
    
    /// @notice Minimum amount of dYFI required to trigger conversion to WETH
    function minDYfiToSell() external view returns (uint64);

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

    /// @notice Sets whether to keep dYFI rewards instead of converting to WETH
    /// @param _keepDYfi New value for keepDYfi flag
    function setKeepDYfi(bool _keepDYfi) external;

    /// @notice Sets whether to keep WETH instead of swapping to strategy asset
    /// @param _keepWeth New value for keepWeth flag
    function setKeepWeth(bool _keepWeth) external;

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
    
    /// @notice Sets the minimum amount of dYFI required to trigger conversion to WETH
    /// @param _minDYfiToSell Minimum amount of dYFI tokens (in wei) needed to execute conversion
    function setMinDYfiToSell(uint64 _minDYfiToSell) external;

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
