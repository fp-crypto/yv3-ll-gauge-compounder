// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

/// @title IGaugeRewards
/// @notice Interface for tracking supply, balances and rewards for all gauges
/// @dev Gauges report changes in values to this contract. Rewards can be harvested by anyone for a fee
interface IGaugeRewards {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Claim(
        address indexed account,
        address receiver,
        uint256 amount,
        uint256 fee_idx,
        uint256 fee
    );

    event Harvest(
        address indexed gauge,
        address account,
        uint256 amount,
        uint256 fee
    );

    event ClaimFees(uint256 fees);
    event SetRedeemer(address redeemer);
    event SetTreasury(address treasury);
    event SetFeeRate(uint256 idx, uint256 rate);
    event PendingManagement(address management);
    event SetManagement(address management);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice The discount token that can be redeemed
    function discount_token() external view returns (address);

    /// @notice The registry contract
    function registry() external view returns (address);

    /// @notice Current management address
    function management() external view returns (address);

    /// @notice Pending management address
    function pending_management() external view returns (address);

    /// @notice The redeemer contract
    function redeemer() external view returns (address);

    /// @notice The treasury address
    function treasury() external view returns (address);

    /// @notice Get packed supply for a gauge
    function packed_supply(address gauge) external view returns (uint256);

    /// @notice Get packed balances for a gauge and account
    function packed_balances(
        address gauge,
        address account
    ) external view returns (uint256);

    /// @notice Get pending rewards for an account
    function pending(address account) external view returns (uint256);

    /// @notice Get packed fees
    function packed_fees() external view returns (uint256);

    /// @notice Get claimable rewards from a single gauge for a specific user
    function claimable(
        address gauge,
        address account
    ) external view returns (uint256);

    /// @notice Get the total supply of a gauge
    function gauge_supply(address gauge) external view returns (uint256);

    /// @notice Get the user balance of a gauge
    function gauge_balance(
        address gauge,
        address account
    ) external view returns (uint256);

    /// @notice Get the amount of pending fees
    function pending_fees() external view returns (uint256);

    /// @notice Get the fee rate of a specific type
    function fee_rates(uint256 idx) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                          MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Claim and optionally redeem rewards
    /// @param gauges Gauges to claim rewards from
    function claim(
        address[] calldata gauges
    ) external payable returns (uint256);

    /// @notice Claim and optionally redeem rewards
    /// @param gauges Gauges to claim rewards from
    /// @param receiver Recipient of the rewards
    function claim(
        address[] calldata gauges,
        address receiver
    ) external payable returns (uint256);

    /// @notice Claim and optionally redeem rewards
    /// @param gauges Gauges to claim rewards from
    /// @param receiver Recipient of the rewards
    /// @param redeem_data Data to pass along to the redeemer
    function claim(
        address[] calldata gauges,
        address receiver,
        bytes calldata redeem_data
    ) external payable returns (uint256);

    /// @notice Harvest gauges for their rewards
    /// @param gauges Gauges to harvest rewards from
    /// @param amounts Reward amounts to harvest
    /// @param receiver Recipient of harvest bounty
    function harvest(
        address[] calldata gauges,
        uint256[] calldata amounts,
        address receiver
    ) external returns (uint256);

    /// @notice Report a change in gauge state
    /// @param ygauge Associated yearn gauge
    /// @param from User that is sender of gauge tokens
    /// @param to User that is receiver of gauge tokens
    /// @param amount Amount of gauge tokens transferred
    /// @param rewards Amount of new reward tokens
    function report(
        address ygauge,
        address from,
        address to,
        uint256 amount,
        uint256 rewards
    ) external;

    /// @notice Claim fees by sending them to the treasury
    function claim_fees() external;

    /// @notice Set a new redeemer contract
    function set_redeemer(address redeemer) external;

    /// @notice Set a new treasury, recipient of fees
    function set_treasury(address treasury) external;

    /// @notice Set the fee rate for a specific fee type
    function set_fee_rate(uint256 idx, uint256 fee) external;

    /// @notice Set the pending management address
    function set_management(address management) external;

    /// @notice Accept management role
    function accept_management() external;
}
