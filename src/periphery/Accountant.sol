// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Governance2Step} from "@periphery/utils/Governance2Step.sol";

/// @title LLGaugeCompounderAccountant
/// @notice Fee management contract for LL Gauge Compounder strategies
/// @dev Calculates fees on strategy profits and allows governance to collect them
contract LLGaugeCompounderAccountant is Governance2Step {
    using SafeERC20 for ERC20;

    /// @notice Fee rate in basis points (default 10%)
    uint256 public feeBps = 1000;

    /// @notice Sets up the accountant with initial governance
    /// @param _governance Address that will control this contract
    constructor(address _governance) Governance2Step(_governance) {}

    /// @notice Calculates performance fees on strategy profits
    /// @dev Only accepts reports from the strategy itself for security
    /// @param strategy Address of the reporting strategy
    /// @param gain Amount of profit generated
    /// @param . loss unused in this implementation
    /// @return totalFees Amount of fees to take from profits
    /// @return . totalRefund unused in this implementation
    function report(
        address strategy,
        uint256 gain,
        uint256 /*loss*/
    ) public returns (uint256 totalFees, uint256 /*totalRefund*/) {
        if (strategy == msg.sender) {
            totalFees = (gain * feeBps) / 10_000;
        }
        return (totalFees, 0);
    }

    /// @notice Updates the fee rate
    /// @param _feeBps New fee rate in basis points (100 = 1%)
    function setFee(uint256 _feeBps) external onlyGovernance {
        feeBps = _feeBps;
    }

    /// @notice Allows governance to collect accumulated fees
    /// @param token Address of the token to withdraw
    function sweep(address token) external onlyGovernance {
        ERC20(token).safeTransfer(
            msg.sender,
            ERC20(token).balanceOf(address(this))
        );
    }
}
