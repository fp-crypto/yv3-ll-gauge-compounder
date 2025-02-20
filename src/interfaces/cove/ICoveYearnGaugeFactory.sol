// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

/**
 * @title ICoveYearnGaugeFactory Interface
 * @notice Interface for the factory contract that deploys and manages Yearn gauge-related contracts for Cove protocol
 * @dev Defines the interface for creating Yearn gauge strategies, auto-compounding gauges, and
 * non-auto-compounding gauges
 */
interface ICoveYearnGaugeFactory {
    /**
     * @dev Struct containing stored information about deployed gauges
     */
    struct GaugeInfoStored {
        /// @dev Address of the Cove Yearn Strategy contract interacting with Yearn Gauge
        address coveYearnStrategy;
        /// @dev Address of the auto-compounding gauge contract for automatic reward reinvestment
        address autoCompoundingGauge;
        /// @dev Address of the non-auto-compounding gauge contract allowing manual reward claims
        address nonAutoCompoundingGauge;
    }

    /**
     * @dev Struct containing comprehensive gauge information
     */
    struct GaugeInfo {
        /// @dev Address of the yearn vault asset (e.g. Curve LP tokens) for depositing into Yearn Vault
        address yearnVaultAsset;
        /// @dev Address of the Yearn Vault accepting yearn vault asset as deposit
        address yearnVault;
        /// @dev Boolean indicating if Yearn Vault is a version 2 vault
        bool isVaultV2;
        /// @dev Address of the Yearn Gauge accepting Yearn Vault as deposit asset
        address yearnGauge;
        /// @dev Address of the Cove's Yearn Strategy using Yearn Gauge as deposit asset
        address coveYearnStrategy;
        /// @dev Address of the auto-compounding gauge using Cove's Yearn Strategy for deposits
        address autoCompoundingGauge;
        /// @dev Address of the non-auto-compounding gauge using Yearn Gauge for deposits and manual rewards
        address nonAutoCompoundingGauge;
    }

    /**
     * @notice Event emitted when Cove gauges are deployed
     * @param yearnGauge Address of the Yearn Gauge
     * @param coveYearnStrategy Address of the Cove Yearn Strategy
     * @param autoCompoundingGauge Address of the auto-compounding gauge
     * @param nonAutoCompoundingGauge Address of the non-auto-compounding gauge
     */
    event CoveGaugesDeployed(
        address yearnGauge,
        address coveYearnStrategy,
        address autoCompoundingGauge,
        address nonAutoCompoundingGauge
    );

    /// @notice Role identifier for the manager role
    function MANAGER_ROLE() external view returns (bytes32);

    /// @notice Role identifier for the pauser role
    function PAUSER_ROLE() external view returns (bytes32);

    /// @notice Address of the Yearn Staking Delegate
    function YEARN_STAKING_DELEGATE() external view returns (address);

    /// @notice Address of the COVE token
    function COVE() external view returns (address);

    /// @notice Current Reward Forwarder implementation address
    function rewardForwarderImpl() external view returns (address);

    /// @notice Current ERC20 Rewards Gauge implementation address
    function erc20RewardsGaugeImpl() external view returns (address);

    /// @notice Current YSD Rewards Gauge implementation address
    function ysdRewardsGaugeImpl() external view returns (address);

    /// @notice Address of the account with gauge admin privileges
    function gaugeAdmin() external view returns (address);

    /// @notice Address of the account with gauge management privileges
    function gaugeManager() external view returns (address);

    /// @notice Address of the account with gauge pausing privileges
    function gaugePauser() external view returns (address);

    /// @notice Get supported Yearn Gauge at index
    function supportedYearnGauges(
        uint256 index
    ) external view returns (address);

    /// @notice Get stored gauge info for a Yearn Gauge
    function yearnGaugeInfoStored(
        address
    ) external view returns (GaugeInfoStored memory);

    /// @notice Returns the number of supported Yearn gauges
    function numOfSupportedYearnGauges() external view returns (uint256);

    /**
     * @notice Retrieves information for all supported Yearn gauges
     * @param limit The maximum number of gauges to fetch information for
     * @param offset The starting gauge index to retrieve data from
     * @return Array of GaugeInfo structs containing details for each supported Yearn gauge
     */
    function getAllGaugeInfo(
        uint256 limit,
        uint256 offset
    ) external view returns (GaugeInfo[] memory);

    /**
     * @notice Retrieves information for a specific Yearn gauge
     * @param yearnGauge The address of the Yearn gauge to retrieve information for
     * @return GaugeInfo struct containing details for the specified Yearn gauge
     */
    function getGaugeInfo(
        address yearnGauge
    ) external view returns (GaugeInfo memory);

    /**
     * @notice Deploys Cove gauges for a given Yearn strategy
     * @param coveYearnStrategy The address of the Cove Yearn strategy for which to deploy gauges
     */
    function deployCoveGauges(address coveYearnStrategy) external;

    /**
     * @notice Sets the implementation address for the RewardForwarder contract
     * @param impl The new implementation address for the RewardForwarder contract
     */
    function setRewardForwarderImplementation(address impl) external;

    /**
     * @notice Sets the implementation address for the YSDRewardsGauge contract
     * @param impl The new implementation address for the YSDRewardsGauge contract
     */
    function setYsdRewardsGaugeImplementation(address impl) external;

    /**
     * @notice Sets the implementation address for the ERC20RewardsGauge contract
     * @param impl The new implementation address for the ERC20RewardsGauge contract
     */
    function setERC20RewardsGaugeImplementation(address impl) external;

    /**
     * @notice Sets the gauge admin address
     * @param admin The new gauge admin address
     */
    function setGaugeAdmin(address admin) external;

    /**
     * @notice Sets the gauge manager address
     * @param manager The new gauge manager address
     */
    function setGaugeManager(address manager) external;

    /**
     * @notice Sets the gauge pauser address
     * @param pauser The new gauge pauser address
     */
    function setGaugePauser(address pauser) external;
}
