// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

/// @title IGauge Interface
/// @notice Interface for 1up Gauge contract that wraps Yearn gauge tokens
/// @dev Implements ERC20 and ERC4626 interfaces
interface IGauge {
    /// @notice Emitted when tokens are transferred
    event Transfer(
        address indexed sender,
        address indexed receiver,
        uint256 value
    );

    /// @notice Emitted when approval is set
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /// @notice Emitted when assets are deposited
    event Deposit(
        address indexed sender,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /// @notice Emitted when assets are withdrawn
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /// @notice The underlying asset address
    function asset() external view returns (address);

    /// @notice The Yearn gauge address
    function ygauge() external view returns (address);

    /// @notice The proxy address
    function proxy() external view returns (address);

    /// @notice The reward token address
    function reward_token() external view returns (address);

    /// @notice The rewards contract address
    function rewards() external view returns (address);

    /// @notice Get the gauge name
    function name() external view returns (string memory);

    /// @notice Get the gauge symbol
    function symbol() external view returns (string memory);

    /// @notice Get the gauge decimals
    function decimals() external view returns (uint8);

    /// @notice Get the gauge total supply
    function totalSupply() external view returns (uint256);

    /// @notice Get the gauge balance of a user
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfer gauge tokens to another user
    function transfer(address to, uint256 value) external returns (bool);

    /// @notice Transfer another user's gauge tokens by spending an allowance
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    /// @notice Approve spending of the caller's gauge tokens
    function approve(address spender, uint256 value) external returns (bool);

    /// @notice Get the allowance for a spender
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /// @notice Get the total amount of assets in the vault
    function totalAssets() external view returns (uint256);

    /// @notice Convert an amount of assets to shares
    function convertToShares(uint256 assets) external view returns (uint256);

    /// @notice Convert an amount of shares to assets
    function convertToAssets(uint256 shares) external view returns (uint256);

    /// @notice Get the maximum amount of assets a user can deposit
    function maxDeposit(address owner) external view returns (uint256);

    /// @notice Preview a deposit
    function previewDeposit(uint256 assets) external view returns (uint256);

    /// @notice Deposit assets
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256);

    /// @notice Get the maximum amount of shares a user can mint
    function maxMint(address owner) external view returns (uint256);

    /// @notice Preview a mint
    function previewMint(uint256 shares) external view returns (uint256);

    /// @notice Mint shares
    function mint(uint256 shares, address receiver) external returns (uint256);

    /// @notice Get the maximum amount of assets a user can withdraw
    function maxWithdraw(address owner) external view returns (uint256);

    /// @notice Preview a withdrawal
    function previewWithdraw(uint256 assets) external view returns (uint256);

    /// @notice Withdraw assets
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256);

    /// @notice Get the maximum amount of shares a user can redeem
    function maxRedeem(address owner) external view returns (uint256);

    /// @notice Preview a redemption
    function previewRedeem(uint256 shares) external view returns (uint256);

    /// @notice Redeem shares
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256);
}
