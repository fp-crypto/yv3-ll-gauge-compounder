// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {OneUpGaugeCompounderStrategy} from "../OneUpGaugeCompounderStrategy.sol";
import {IBaseLLGaugeCompounderStrategy as IStrategyInterface} from "../interfaces/IBaseLLGaugeCompounderStrategy.sol";
import {IRegistry} from "../interfaces/veyfi/IRegistry.sol";

contract LLGaugeCompounderStrategiesFactory {
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

    struct LLStrategyTriple {
        address coveStrategy;
        address oneUpStrategy;
        address stakeDaoStrategy;
    }

    /// @notice Track the deployments. yGauge => strategy
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

    function newStrategiesGroup(
        address _yVault,
        string calldata _name,
        uint24 _assetSwapFee
    ) external virtual returns (LLStrategyTriple memory _group) {
        address _yGauge = GAUGE_REGISTRY.vault_gauge_map(_yVault);
        require(_yGauge != address(0), "!gauge");

        _group.oneUpStrategy = new1UpStrategy(_yGauge, _name, _assetSwapFee);
    }

    /// @notice Deploy a new Strategy
    /// @dev Creates a new Strategy instance and sets up all the required roles
    /// @param _yGauge The yearn gauge being compounded
    /// @param _name The name for the strategy token
    /// @param _assetSwapFee Uniswap asset swap fee
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
                new OneUpGaugeCompounderStrategy(
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

        //emit NewStrategy(address(_newStrategy), _newStrategy.asset(), "1up");

        deployments[_yGauge].oneUpStrategy = address(_newStrategy);
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
