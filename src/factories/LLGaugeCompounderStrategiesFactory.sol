// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {BaseLLGaugeCompounderStrategyFactory} from "./BaseLLGaugeCompounderStrategyFactory.sol";
import {IBaseLLGaugeCompounderStrategy} from "../interfaces/IBaseLLGaugeCompounderStrategy.sol";
import {IRegistry} from "../interfaces/veyfi/IRegistry.sol";

/// @title LLGaugeCompounderStrategiesFactory
/// @notice Factory contract for deploying Liquid Locker gauge compounder strategies
/// @dev Handles deployment and initialization of strategies for different LL providers (Cove, 1UP, StakeDAO)
/// @dev Acts as a coordinator for the individual provider factories
contract LLGaugeCompounderStrategiesFactory {
    /// @notice Registry contract that maps yVaults to their corresponding gauges
    /// @dev Used to look up gauge addresses for yVaults
    IRegistry public constant GAUGE_REGISTRY =
        IRegistry(0x1D0fdCb628b2f8c0e22354d45B3B2D4cE9936F8B);

    /// @notice Address of the Cove strategy factory
    /// @dev Immutable reference to the factory for Cove strategies
    address private immutable COVE_FACTORY;

    /// @notice Address of the 1UP strategy factory
    /// @dev Immutable reference to the factory for 1UP strategies
    address private immutable ONE_UP_FACTORY;

    /// @notice Address of the StakeDAO strategy factory
    /// @dev Immutable reference to the factory for StakeDAO strategies
    address private immutable STAKE_DAO_FACTORY;

    /// @notice Structure to hold related deployments for a single gauge
    /// @dev Groups together Cove, 1UP, and StakeDAO contracts for the same gauge
    struct LLTriple {
        address cove;
        address oneUp;
        address stakeDao;
    }

    /// @notice Initializes the factory with addresses of the individual provider factories
    /// @param coveGaugeCompounderStrategyFactory Address of the Cove strategy factory
    /// @param oneUpGaugeCompounderStrategyFactory Address of the 1UP strategy factory
    /// @param stakeDaoGaugeCompounderStrategyFactory Address of the StakeDAO strategy factory
    constructor(
        address coveGaugeCompounderStrategyFactory,
        address oneUpGaugeCompounderStrategyFactory,
        address stakeDaoGaugeCompounderStrategyFactory
    ) {
        COVE_FACTORY = coveGaugeCompounderStrategyFactory;
        ONE_UP_FACTORY = oneUpGaugeCompounderStrategyFactory;
        STAKE_DAO_FACTORY = stakeDaoGaugeCompounderStrategyFactory;
    }

    /// @notice Deploys a group of strategies for a given yVault
    /// @dev Deploys Cove, 1UP, and StakeDAO strategies for the given vault
    /// @param _yVault The yearn vault address to create strategies for
    /// @param _name The base name for the strategy tokens
    /// @param _assetSwapFee Uniswap pool fee for asset swaps (in hundredths of a bip)
    /// @return LLTriple Struct containing addresses of all deployed strategies
    /// @dev Reverts if the vault doesn't have a corresponding gauge
    function newStrategiesGroup(
        address _yVault,
        string calldata _name,
        uint24 _assetSwapFee
    ) external returns (LLTriple memory) {
        address _yGauge = GAUGE_REGISTRY.vault_gauge_map(_yVault);
        require(_yGauge != address(0), "!gauge");

        return
            LLTriple({
                cove: BaseLLGaugeCompounderStrategyFactory(COVE_FACTORY)
                    .newStrategy(_yVault, _name, _assetSwapFee),
                oneUp: BaseLLGaugeCompounderStrategyFactory(ONE_UP_FACTORY)
                    .newStrategy(_yVault, _name, _assetSwapFee),
                stakeDao: BaseLLGaugeCompounderStrategyFactory(
                    STAKE_DAO_FACTORY
                ).newStrategy(_yVault, _name, _assetSwapFee)
            });
    }

    /// @notice Returns the addresses of all individual provider factories
    /// @return LLTriple Struct containing addresses of the Cove, 1UP, and StakeDAO factories
    function factories() external view returns (LLTriple memory) {
        return
            LLTriple({
                cove: COVE_FACTORY,
                oneUp: ONE_UP_FACTORY,
                stakeDao: STAKE_DAO_FACTORY
            });
    }

    /// @notice Returns the addresses of all strategies deployed for a given gauge
    /// @param _yGauge Address of the yearn gauge
    /// @return LLTriple Struct containing addresses of the Cove, 1UP, and StakeDAO strategies
    /// @dev Returns zero addresses if no strategies have been deployed for the gauge
    function deployments(
        address _yGauge
    ) public view returns (LLTriple memory) {
        return
            LLTriple({
                cove: BaseLLGaugeCompounderStrategyFactory(COVE_FACTORY)
                    .deployments(_yGauge),
                oneUp: BaseLLGaugeCompounderStrategyFactory(ONE_UP_FACTORY)
                    .deployments(_yGauge),
                stakeDao: BaseLLGaugeCompounderStrategyFactory(
                    STAKE_DAO_FACTORY
                ).deployments(_yGauge)
            });
    }

    /// @notice Checks if a strategy was deployed by this factory
    /// @dev Verifies if the strategy address matches the recorded deployment for its asset
    /// @param _strategy Address of the strategy to check
    /// @return bool True if the strategy was deployed by this factory, false otherwise
    /// @dev Returns false for zero address or if the strategy's vault doesn't have a gauge
    function isDeployedStrategy(
        address _strategy
    ) external view returns (bool) {
        if (_strategy == address(0)) return false;

        address _vault = IBaseLLGaugeCompounderStrategy(_strategy).vault();
        address _yGauge = GAUGE_REGISTRY.vault_gauge_map(_vault);

        LLTriple memory _strategies = deployments(_yGauge);

        return
            _yGauge != address(0) &&
            (_strategies.cove == _strategy ||
                _strategies.oneUp == _strategy ||
                _strategies.stakeDao == _strategy);
    }
}
