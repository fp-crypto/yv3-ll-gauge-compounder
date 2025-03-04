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
    /// @param locker Type of locker used (e.g., "cove", "1up", "stakedao")
    event NewStrategy(address indexed strategy, address indexed asset, string locker);

    IRegistry public constant GAUGE_REGISTRY =
        IRegistry(0x1D0fdCb628b2f8c0e22354d45B3B2D4cE9936F8B);
    address public immutable emergencyAdmin;

    address public management;
    address public performanceFeeRecipient;
    address public keeper;


    /// @notice Track the deployments for each gauge
    /// @dev Maps yGauge address to its corresponding strategy address
    mapping(address => address) public deployments;

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
    ) {
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
        emergencyAdmin = _emergencyAdmin;
    }

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
    ) external virtual returns (address);

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
