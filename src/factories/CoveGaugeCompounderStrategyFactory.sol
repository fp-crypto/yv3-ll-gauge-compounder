// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {BaseLLGaugeCompounderStrategyFactory, IBaseLLGaugeCompounderStrategy} from "./BaseLLGaugeCompounderStrategyFactory.sol";
import {CoveGaugeCompounderStrategy} from "../CoveGaugeCompounderStrategy.sol";

/// @title CoveGaugeCompounderStrategyFactory
/// @notice Factory contract for deploying Cove Liquid Locker gauge compounder strategies
/// @dev Extends BaseLLGaugeCompounderStrategyFactory to create Cove-specific strategies
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

    /// @notice Deploys a new Cove strategy for a given gauge
    /// @dev Implements the abstract function from BaseLLGaugeCompounderStrategyFactory
    /// @param _yGauge The yearn gauge address to create a strategy for
    /// @param _assetSwapFee Uniswap pool fee for asset swaps (in hundredths of a bip)
    /// @param _parentVault Address of the parent allocator vault that will distribute funds to this strategy
    /// @return Implementation of IBaseLLGaugeCompounderStrategy
    function _newStrategy(
        address _yGauge,
        uint24 _assetSwapFee,
        address _parentVault
    ) internal override returns (IBaseLLGaugeCompounderStrategy) {
        return
            IBaseLLGaugeCompounderStrategy(
                address(
                    new CoveGaugeCompounderStrategy(
                        _yGauge,
                        _assetSwapFee,
                        _parentVault
                    )
                )
            );
    }
}
