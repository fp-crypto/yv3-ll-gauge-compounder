// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {BaseLLGaugeCompounderStrategyFactory, IBaseLLGaugeCompounderStrategy} from "./BaseLLGaugeCompounderStrategyFactory.sol";
import {CoveGaugeCompounderStrategy} from "../CoveGaugeCompounderStrategy.sol";

/// @title BaseGaugeCompounderStrategyFactory
/// @notice Abstract base factory contract for deploying Liquid Locker gauge compounder strategies
/// @dev Provides common functionality for strategy factories to be extended by specific implementations
contract CoveGaugeCompounderStrategyFactory is
    BaseLLGaugeCompounderStrategyFactory
{
    /// @notice Initializes the factory with the core protocol roles
    /// @param _management Address that will have management rights over strategies
    /// @param _performanceFeeRecipient Address that will receive performance fees
    /// @param _keeper Address that will be able to tend/harvest strategies
    /// @param _emergencyAdmin Address that will have emergency powers
    constructor(
        address _management,
        address _performanceFeeRecipient,
        address _keeper,
        address _emergencyAdmin
    )
        BaseLLGaugeCompounderStrategyFactory(
            _management,
            _performanceFeeRecipient,
            _keeper,
            _emergencyAdmin
        )
    {}

    /// @notice Deploys a new strategy for a given yVault
    /// @dev Abstract function to be implemented by derived factories
    /// @param _yVault The yearn vault address to create a strategy for
    /// @param _name The base name for the strategy token
    /// @param _assetSwapFee Uniswap pool fee for asset swaps
    /// @return Implementation of IBaseLLGaugeCompounderStrategy
    function newStrategy(
        address _yVault,
        string calldata _name,
        uint24 _assetSwapFee
    ) external override returns (address) {
        address _yGauge = getGauge(_yVault);
        require(_yGauge != address(0), "no gauge");
        require(deployments[_yGauge] == address(0), "exists");

        // tokenized strategies available setters.
        IBaseLLGaugeCompounderStrategy _newStrategy = IBaseLLGaugeCompounderStrategy(
                address(
                    new CoveGaugeCompounderStrategy(
                        _yGauge,
                        _name,
                        _assetSwapFee
                    )
                )
            );

        _newStrategy.setPerformanceFeeRecipient(performanceFeeRecipient);
        _newStrategy.setKeeper(keeper);
        _newStrategy.setPendingManagement(management);
        _newStrategy.setEmergencyAdmin(emergencyAdmin);

        deployments[_yGauge] = address(_newStrategy);
        emit NewStrategy(address(_newStrategy), _newStrategy.asset(), "cove");
        return address(_newStrategy);
    }
}
