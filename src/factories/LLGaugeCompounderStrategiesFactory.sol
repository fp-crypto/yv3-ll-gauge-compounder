// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {CoveGaugeCompounderStrategy} from "../CoveGaugeCompounderStrategy.sol";
import {OneUpGaugeCompounderStrategy} from "../OneUpGaugeCompounderStrategy.sol";
import {StakeDaoGaugeCompounderStrategy} from "../StakeDaoCompounderStrategy.sol";
import {IBaseLLGaugeCompounderStrategy as IStrategyInterface} from "../interfaces/IBaseLLGaugeCompounderStrategy.sol";
import {IRegistry} from "../interfaces/veyfi/IRegistry.sol";

/// @title LLGaugeCompounderStrategiesFactory
/// @notice Factory contract for deploying Liquid Locker gauge compounder strategies
/// @dev Handles deployment and initialization of strategies for different LL providers (Cove, 1UP, StakeDAO)
contract LLGaugeCompounderStrategiesFactory {
    /// @notice Emitted when a new strategy is deployed
    /// @param strategy Address of the newly deployed strategy
    /// @param asset Address of the underlying asset
    /// @param locker Name of the liquid locker provider (e.g., "cove", "1up")
    event NewStrategy(
        address indexed strategy,
        address indexed asset,
        string locker
    );

    IRegistry public constant GAUGE_REGISTRY =
        IRegistry(0x1D0fdCb628b2f8c0e22354d45B3B2D4cE9936F8B);
    address public immutable emergencyAdmin;

    address public management;
    address public performanceFeeRecipient;
    address public keeper;

    /// @notice Structure to hold related strategy deployments for a single gauge
    /// @dev Groups together Cove, 1UP, and StakeDAO strategies for the same gauge
    struct LLStrategyTriple {
        address coveStrategy;
        address oneUpStrategy;
        address stakeDaoStrategy;
    }

    /// @notice Track the deployments for each gauge
    /// @dev Maps yGauge address to a struct containing all three strategy addresses
    mapping(address => LLStrategyTriple) public deployments;

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

    /// @notice Deploys a group of strategies for a given yVault
    /// @dev Deploys Cove, 1UP, and StakeDAO strategies for the given vault
    /// @param _yVault The yearn vault address to create strategies for
    /// @param _name The base name for the strategy tokens
    /// @param _assetSwapFee Uniswap pool fee for asset swaps
    /// @return _group Struct containing addresses of all deployed strategies
    function newStrategiesGroup(
        address _yVault,
        string calldata _name,
        uint24 _assetSwapFee
    ) external virtual returns (LLStrategyTriple memory _group) {
        address _yGauge = GAUGE_REGISTRY.vault_gauge_map(_yVault);
        require(_yGauge != address(0), "!gauge");

        _group.coveStrategy = newCoveStrategy(_yGauge, _name, _assetSwapFee);
        _group.oneUpStrategy = new1UpStrategy(_yGauge, _name, _assetSwapFee);
        _group.stakeDaoStrategy = newStakeDaoStrategy(
            _yGauge,
            _name,
            _assetSwapFee
        );
    }

    /// @notice Deploy a new 1UP Strategy
    /// @dev Creates a new 1UP Strategy instance and sets up all the required roles
    /// @param _yGauge The yearn gauge being compounded
    /// @param _name The name for the strategy token
    /// @param _assetSwapFee Uniswap pool fee for asset swaps
    /// @return address The address of the newly deployed strategy
    function new1UpStrategy(
        address _yGauge,
        string calldata _name,
        uint24 _assetSwapFee
    ) public virtual returns (address) {
        require(deployments[_yGauge].oneUpStrategy == address(0), "exists");

        // tokenized strategies available setters.
        IStrategyInterface _newStrategy = IStrategyInterface(
            address(
                new OneUpGaugeCompounderStrategy(_yGauge, _name, _assetSwapFee)
            )
        );

        _newStrategy.setPerformanceFeeRecipient(performanceFeeRecipient);
        _newStrategy.setKeeper(keeper);
        _newStrategy.setPendingManagement(management);
        _newStrategy.setEmergencyAdmin(emergencyAdmin);

        emit NewStrategy(address(_newStrategy), _newStrategy.asset(), "cove");

        deployments[_yGauge].oneUpStrategy = address(_newStrategy);
        return address(_newStrategy);
    }

    /// @notice Deploy a new Cove Strategy
    /// @dev Creates a new Cove Strategy instance and sets up all the required roles
    /// @param _yGauge The yearn gauge being compounded
    /// @param _name The name for the strategy token
    /// @param _assetSwapFee Uniswap pool fee for asset swaps
    /// @return address The address of the newly deployed strategy
    function newCoveStrategy(
        address _yGauge,
        string calldata _name,
        uint24 _assetSwapFee
    ) public virtual returns (address) {
        require(deployments[_yGauge].coveStrategy == address(0), "exists");

        // tokenized strategies available setters.
        IStrategyInterface _newStrategy = IStrategyInterface(
            address(
                new CoveGaugeCompounderStrategy(_yGauge, _name, _assetSwapFee)
            )
        );

        _newStrategy.setPerformanceFeeRecipient(performanceFeeRecipient);
        _newStrategy.setKeeper(keeper);
        _newStrategy.setPendingManagement(management);
        _newStrategy.setEmergencyAdmin(emergencyAdmin);

        emit NewStrategy(address(_newStrategy), _newStrategy.asset(), "1up");

        deployments[_yGauge].coveStrategy = address(_newStrategy);
        return address(_newStrategy);
    }

    /// @notice Deploy a new StakeDAO Strategy
    /// @dev Creates a new StakeDAO Strategy instance and sets up all the required roles
    /// @param _yGauge The yearn gauge being compounded
    /// @param _name The name for the strategy token
    /// @param _assetSwapFee Uniswap pool fee for asset swaps
    /// @return address The address of the newly deployed strategy
    function newStakeDaoStrategy(
        address _yGauge,
        string calldata _name,
        uint24 _assetSwapFee
    ) public virtual returns (address) {
        require(deployments[_yGauge].stakeDaoStrategy == address(0), "exists");

        // tokenized strategies available setters.
        IStrategyInterface _newStrategy = IStrategyInterface(
            address(
                new StakeDaoGaugeCompounderStrategy(
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

        emit NewStrategy(address(_newStrategy), _newStrategy.asset(), "StakeDao");

        deployments[_yGauge].stakeDaoStrategy = address(_newStrategy);
        return address(_newStrategy);
    }

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
        address _vault = IStrategyInterface(_strategy).vault();
        address _yGauge = GAUGE_REGISTRY.vault_gauge_map(_vault);

        return
            _yGauge != address(0) &&
            (deployments[_yGauge].coveStrategy == _strategy ||
                deployments[_yGauge].oneUpStrategy == _strategy ||
                deployments[_yGauge].stakeDaoStrategy == _strategy);
    }
}
