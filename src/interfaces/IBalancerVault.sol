// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

interface IBalancerVault {
    struct FlashLoanRequest {
        address[] tokens;
        uint256[] amounts;
    }

    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

