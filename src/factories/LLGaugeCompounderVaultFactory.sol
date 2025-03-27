// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {BaseLLGaugeCompounderStrategyFactory} from "./BaseLLGaugeCompounderStrategyFactory.sol";
import {IBaseLLGaugeCompounderStrategy} from "../interfaces/IBaseLLGaugeCompounderStrategy.sol";
import {IRegistry} from "../interfaces/veyfi/IRegistry.sol";
import {IReleaseRegistry} from "../interfaces/IReleaseRegistry.sol";
import {IVaultFactory} from "../interfaces/IVaultFactory.sol";
import {IVault} from "../interfaces/IVault.sol";
import {Roles} from "../interfaces/Roles.sol";

/// @title LLGaugeCompounderVaultFactory
/// @notice Factory contract for deploying Liquid Locker gauge compounder strategies
/// @dev Handles deployment and initialization of strategies for different LL providers (Cove, 1UP, StakeDAO)
/// @dev Acts as a coordinator for the individual provider factories
contract LLGaugeCompounderVaultFactory {
    /// @notice Registry contract that maps yVaults to their corresponding gauges
    /// @dev Used to look up gauge addresses for yVaults
    IRegistry public constant GAUGE_REGISTRY =
        IRegistry(0x1D0fdCb628b2f8c0e22354d45B3B2D4cE9936F8B);

    IReleaseRegistry public constant RELEASE_REGISTRY =
        IReleaseRegistry(0x0377b4daDDA86C89A0091772B79ba67d0E5F7198);

    address public immutable ROLE_MANAGER;

    /// @notice Address of the Cove strategy factory
    /// @dev Immutable reference to the factory for Cove strategies
    address private immutable COVE_FACTORY;

    /// @notice Address of the 1UP strategy factory
    /// @dev Immutable reference to the factory for 1UP strategies
    address private immutable ONE_UP_FACTORY;

    /// @notice Address of the StakeDAO strategy factory
    /// @dev Immutable reference to the factory for StakeDAO strategies
    address private immutable STAKE_DAO_FACTORY;

    // TODO: find a good default
    uint256 private constant DEFAULT_PROFIT_UNLOCK_TIME = 6 hours;

    /// @notice Track the deployments for each gauge
    /// @dev Maps yGauge address to its corresponding vault address
    mapping(address => address) public deployments;

    /// @notice Structure to hold related deployments for a single gauge
    /// @dev Groups together Cove, 1UP, and StakeDAO contracts for the same gauge
    struct LLTriple {
        address cove;
        address oneUp;
        address stakeDao;
    }

    /// @notice Initializes the factory with addresses of the individual provider factories
    /// @param _roleManager Address of the role manager for vault permissions
    /// @param _coveGaugeCompounderStrategyFactory Address of the Cove strategy factory
    /// @param _oneUpGaugeCompounderStrategyFactory Address of the 1UP strategy factory
    /// @param _stakeDaoGaugeCompounderStrategyFactory Address of the StakeDAO strategy factory
    constructor(
        address _roleManager,
        address _coveGaugeCompounderStrategyFactory,
        address _oneUpGaugeCompounderStrategyFactory,
        address _stakeDaoGaugeCompounderStrategyFactory
    ) {
        ROLE_MANAGER = _roleManager;
        COVE_FACTORY = _coveGaugeCompounderStrategyFactory;
        ONE_UP_FACTORY = _oneUpGaugeCompounderStrategyFactory;
        STAKE_DAO_FACTORY = _stakeDaoGaugeCompounderStrategyFactory;
    }

    /// @notice Creates a new vault with LL gauge compounder strategies
    /// @dev Deploys a vault and adds Cove, 1UP, and StakeDAO strategies to it
    /// @param _yVault The yearn vault address to create strategies for
    /// @param _name The name for the vault
    /// @param _symbol The symbol for the vault
    /// @param _assetSwapFee Uniswap pool fee for asset swaps (in hundredths of a bip)
    /// @return Address of the newly created vault
    /// @dev Reverts if the vault doesn't have a corresponding gauge or if a vault already exists for this gauge
    function newLLCompounderVault(
        address _yVault,
        string calldata _name,
        string calldata _symbol,
        uint24 _assetSwapFee
    ) external returns (address) {
        address _yGauge = GAUGE_REGISTRY.vault_gauge_map(_yVault);
        require(_yGauge != address(0), "!gauge");
        require(deployments[_yGauge] == address(0), "exists");

        IVaultFactory _vaultFactory = IVaultFactory(
            RELEASE_REGISTRY.latestFactory()
        );
        IVault _vault = IVault(
            _vaultFactory.deploy_new_vault(
                IVault(_yVault).asset(),
                _name,
                _symbol,
                address(this),
                DEFAULT_PROFIT_UNLOCK_TIME
            )
        );

        uint256 roles = Roles.ADD_STRATEGY_MANAGER |
            Roles.DEPOSIT_LIMIT_MANAGER |
            Roles.MAX_DEBT_MANAGER;
        _vault.set_role(address(this), roles);
        _vault.set_deposit_limit(type(uint256).max);

        LLTriple memory _strategies = strategyDeployments(_yGauge);

        if (_strategies.cove == address(0))
            _strategies.cove = BaseLLGaugeCompounderStrategyFactory(
                COVE_FACTORY
            ).newStrategy(_yGauge, _assetSwapFee);
        if (_strategies.oneUp == address(0))
            _strategies.oneUp = BaseLLGaugeCompounderStrategyFactory(
                ONE_UP_FACTORY
            ).newStrategy(_yGauge, _assetSwapFee);
        if (_strategies.stakeDao == address(0))
            _strategies.stakeDao = BaseLLGaugeCompounderStrategyFactory(
                STAKE_DAO_FACTORY
            ).newStrategy(_yGauge, _assetSwapFee);

        _vault.add_strategy(_strategies.cove, true);
        _vault.update_max_debt_for_strategy(
            _strategies.cove,
            type(uint256).max
        );
        _vault.add_strategy(_strategies.oneUp, true);
        _vault.update_max_debt_for_strategy(
            _strategies.oneUp,
            type(uint256).max
        );
        _vault.add_strategy(_strategies.stakeDao, true);
        _vault.update_max_debt_for_strategy(
            _strategies.stakeDao,
            type(uint256).max
        );

        _vault.remove_role(address(this), roles);
        _vault.transfer_role_manager(ROLE_MANAGER);

        deployments[_yGauge] = address(_vault);

        return address(_vault);
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
    function strategyDeployments(
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

    /// @notice Retrieves the addresses of all strategies deployed for a given vault
    /// @param _yVault Address of the base yearn vault
    /// @return LLTriple Struct containing addresses of the Cove, 1UP, and StakeDAO strategies
    /// @dev Looks up the gauge for the vault and then returns the strategies for that gauge
    /// @dev Returns zero addresses for strategies that haven't been deployed
    function strategyDeploymentsByVault(
        address _yVault
    ) external view returns (LLTriple memory) {
        address _yGauge = GAUGE_REGISTRY.vault_gauge_map(_yVault);
        return strategyDeployments(_yGauge);
    }

    /// @notice Checks if a strategy was deployed through one of the factory's provider factories
    /// @dev Verifies if the strategy address matches any of the strategies deployed for its gauge
    /// @param _strategy Address of the strategy to check
    /// @return bool True if the strategy was deployed by one of the provider factories, false otherwise
    /// @dev Returns false for zero address or if the strategy's vault doesn't have a gauge
    function isDeployedStrategy(
        address _strategy
    ) external view returns (bool) {
        if (_strategy == address(0)) return false;

        address _vault = IBaseLLGaugeCompounderStrategy(_strategy).vault();
        address _yGauge = GAUGE_REGISTRY.vault_gauge_map(_vault);

        LLTriple memory _strategies = strategyDeployments(_yGauge);

        return
            _yGauge != address(0) &&
            (_strategies.cove == _strategy ||
                _strategies.oneUp == _strategy ||
                _strategies.stakeDao == _strategy);
    }
}
