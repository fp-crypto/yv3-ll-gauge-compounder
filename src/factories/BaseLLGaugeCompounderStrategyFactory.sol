// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {IBaseLLGaugeCompounderStrategy} from "../interfaces/IBaseLLGaugeCompounderStrategy.sol";
import {IRegistry} from "../interfaces/veyfi/IRegistry.sol";

/// @title BaseLLGaugeCompounderStrategyFactory
/// @notice Abstract base factory contract for deploying Liquid Locker gauge compounder strategies
/// @dev Provides common functionality for strategy factories to be extended by specific implementations
abstract contract BaseLLGaugeCompounderStrategyFactory {
    /// @notice Emitted when a new strategy is deployed
    /// @param strategy Address of the newly deployed strategy
    /// @param asset Address of the underlying asset
    event NewStrategy(address indexed strategy, address indexed asset);

    /// @notice Registry contract that maps yVaults to their corresponding gauges
    /// @dev Used to look up gauge addresses for yVaults
    IRegistry public constant GAUGE_REGISTRY =
        IRegistry(0x1D0fdCb628b2f8c0e22354d45B3B2D4cE9936F8B);

    /// @notice Address with emergency powers over deployed strategies
    /// @dev Set at construction time and cannot be changed
    address public immutable emergencyAdmin;

    /// @notice Address with management rights over deployed strategies
    /// @dev Can be updated by current management
    address public management;
    /// @notice Address that receives performance fees from deployed strategies
    /// @dev Can be updated by current management
    address public performanceFeeRecipient;

    /// @notice Address that can call tend/harvest on deployed strategies
    /// @dev Can be updated by current management
    address public keeper;

    /// @notice Track the deployments for each gauge
    /// @dev Maps yGauge address to its corresponding strategy address
    mapping(address => address) public deployments;

    /// @dev Only one strategy per gauge per factory is allowed
    /// @param _management Address that will have management rights over strategies
    /// @param _performanceFeeRecipient Address that will receive performance fees
    /// @param _keeper Address that will be able to tend/harvest strategies
    /// @param _emergencyAdmin Address that will have emergency powers
    constructor(
        address _management,
        address _performanceFeeRecipient,
        address _keeper,
        address _emergencyAdmin
    ) {
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
        emergencyAdmin = _emergencyAdmin;
    }

    /// @notice Deploys a new strategy for a given yVault
    /// @param _yVault The yearn vault address to create a strategy for
    /// @param _assetSwapFee Uniswap pool fee for asset swaps
    /// @return Implementation of IBaseLLGaugeCompounderStrategy
    function newStrategy(
        address _yVault,
        uint24 _assetSwapFee
    ) external returns (address) {
        address _yGauge = getGauge(_yVault);
        require(_yGauge != address(0), "no gauge");
        require(deployments[_yGauge] == address(0), "exists");

        // tokenized strategies available setters.
        IBaseLLGaugeCompounderStrategy _strategy = _newStrategy(
            _yGauge,
            _assetSwapFee
        );

        _strategy.setPerformanceFeeRecipient(performanceFeeRecipient);
        _strategy.setKeeper(keeper);
        _strategy.setPendingManagement(management);
        _strategy.setEmergencyAdmin(emergencyAdmin);

        deployments[_yGauge] = address(_strategy);
        emit NewStrategy(address(_strategy), _strategy.asset());
        return address(_strategy);
    }

    /// @notice Deploys a new strategy for a given gauge
    /// @dev Abstract function to be implemented by derived factories
    /// @param _yGauge The yearn gauge address to create a strategy for
    /// @param _assetSwapFee Uniswap pool fee for asset swaps (in hundredths of a bip)
    /// @return Implementation of IBaseLLGaugeCompounderStrategy
    function _newStrategy(
        address _yGauge,
        uint24 _assetSwapFee
    ) internal virtual returns (IBaseLLGaugeCompounderStrategy);

    /// @notice Updates the core protocol roles
    /// @dev Can only be called by current management
    /// @param _management New management address
    /// @param _performanceFeeRecipient New fee recipient address
    /// @param _keeper New keeper address
    function setAddresses(
        address _management,
        address _performanceFeeRecipient,
        address _keeper
    ) external {
        require(msg.sender == management, "!management");
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
    }

    /// @notice Checks if a strategy was deployed by this factory
    /// @dev Verifies if the strategy address matches the recorded deployment for its asset
    /// @param _strategy Address of the strategy to check
    /// @return bool True if the strategy was deployed by this factory, false otherwise
    function isDeployedStrategy(
        address _strategy
    ) external view returns (bool) {
        address _vault = IBaseLLGaugeCompounderStrategy(_strategy).vault();
        address _yGauge = GAUGE_REGISTRY.vault_gauge_map(_vault);

        return _yGauge != address(0) && deployments[_yGauge] == _strategy;
    }

    /// @notice Gets the gauge address associated with a vault
    /// @param _yVault The yearn vault address to check
    /// @return address The gauge address for the vault, or address(0) if none exists
    function getGauge(address _yVault) internal view returns (address) {
        return GAUGE_REGISTRY.vault_gauge_map(_yVault);
    }

    /// @notice Checks if a vault has an associated gauge
    /// @param _yVault The yearn vault address to check
    /// @return bool True if the vault has a gauge, false otherwise
    function hasGauge(address _yVault) internal view returns (bool) {
        return getGauge(_yVault) != address(0);
    }
}
