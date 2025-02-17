// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IDYFIRedeemer {
    /// @notice Returns the address of the current owner.
    function owner() external view returns (address);

    /// @notice Returns the address of the pending owner.
    function pending_owner() external view returns (address);

    /// @notice Returns whether the contract is killed.
    function killed() external view returns (bool);

    /// @notice Returns the address of the payee for ETH redemptions.
    function payee() external view returns (address);

    /// @notice Returns the packed scaling factor parameters.
    function packed_scaling_factor() external view returns (uint256);

    /**
     * @notice Redeem dYFI for YFI using ETH.
     * @dev Redemption tolerates a 0.3% negative or positive slippage.
     * @param amount The amount of dYFI to spend.
     * @param recipient The address to receive the redeemed YFI.
     * @return The amount of YFI redeemed.
     */
    function redeem(
        uint256 amount,
        address recipient
    ) external payable returns (uint256);

    /**
     * @notice Get the current dYFI redemption discount.
     * @return The redemption discount (18 decimals).
     * @dev Discount formula is `1/(1 + 10 e^(4.7(s*x - 1)))`, where `x = veyfi supply / yfi supply`.
     */
    function discount() external view returns (uint256);

    /**
     * @notice Estimate the required amount of ETH to redeem the given amount of dYFI.
     * @param amount The amount of dYFI to redeem.
     * @return The amount of ETH required.
     */
    function eth_required(uint256 amount) external view returns (uint256);

    /**
     * @notice Get the latest price of YFI in ETH.
     * @return The price of YFI in ETH (18 decimals).
     */
    function get_latest_price() external view returns (uint256);

    /**
     * @notice Get the current discount curve scaling factor.
     * @return The scaling factor (18 decimals).
     */
    function scaling_factor() external view returns (uint256);

    /**
     * @notice Get the current discount curve scaling factor ramp parameters.
     * @return A tuple containing:
     *         - Ramp start timestamp
     *         - Ramp end timestamp
     *         - Ramp start scaling factor
     *         - Ramp end scaling factor
     */
    function scaling_factor_ramp()
        external
        view
        returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Set the payee address for ETH redemptions.
     * @dev Can only be called by the owner.
     * @param new_payee The new payee address.
     */
    function set_payee(address new_payee) external;

    /**
     * @notice Start ramping the scaling factor.
     * @dev Can only be called by the owner.
     * @param newScalingFactor The new scaling factor (18 decimals).
     * @param duration The duration of the ramp in seconds.
     * @param start The start timestamp of the ramp.
     */
    function start_ramp(
        uint256 newScalingFactor,
        uint256 duration,
        uint256 start
    ) external;

    /**
     * @notice Stop the currently active scaling factor ramp.
     * @dev Can only be called by the owner.
     */
    function stop_ramp() external;

    /**
     * @notice Kill the contract, preventing further redemptions and reclaiming YFI.
     * @dev Can only be called by the owner.
     */
    function kill() external;

    /**
     * @notice Sweep tokens from the contract.
     * @dev Can only be called by the owner.
     * @param token The address of the token to sweep.
     * @return The amount of tokens swept.
     */
    function sweep(address token) external returns (uint256);

    /**
     * @notice Initiate the transfer of ownership to a new address.
     * @dev Can only be called by the owner.
     * @param new_owner The address of the new owner.
     */
    function transfer_ownership(address new_owner) external;

    /**
     * @notice Accept the ownership transfer.
     * @dev Can only be called by the pending owner.
     */
    function accept_ownership() external;
}
