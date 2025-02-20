// SPDX-License-Identifier: GPLv3
pragma solidity ^0.8.18;

interface IYearnStrategy {
    event GovernanceChanged(address indexed newGovernance);
    event Upgraded(address indexed implementation);
    function DENOMINATOR() external view returns (uint256);
    function SDTDistributor() external view returns (address);
    function acceptGovernance() external;
    function acceptRewardDistributorOwnership(
        address rewardDistributor
    ) external;
    function accumulator() external view returns (address);
    function addRewardToken(address gauge, address extraRewardToken) external;
    function allowAddress(address _address) external;
    function allowed(address) external view returns (bool);
    function balanceOf(address asset) external view returns (uint256);
    function claimDYFIRewardPool() external;
    function claimIncentiveFee() external view returns (uint256);
    function claimNativeRewards() external;
    function claimProtocolFees() external;
    function deposit(address asset, uint256 amount) external;
    function disallowAddress(address _address) external;
    function dyfiRewardPool() external view returns (address);
    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool, bytes memory);
    function factory() external view returns (address);
    function feeDistributor() external view returns (address);
    function feeReceiver() external view returns (address);
    function feeRewardToken() external view returns (address);
    function feesAccrued() external view returns (uint256);
    function futureGovernance() external view returns (address);
    function gauges(address) external view returns (address);
    function governance() external view returns (address);
    function harvest(
        address asset,
        bool distributeSDT,
        bool claimExtra
    ) external;
    function initialize(address owner) external;
    function lGaugeType(address) external view returns (uint256);
    function locker() external view returns (address);
    function migrateLP(address asset) external;
    function minter() external view returns (address);
    function protocolFeesPercent() external view returns (uint256);
    function proxiableUUID() external view returns (bytes32);
    function rewardDistributors(address) external view returns (address);
    function rewardReceivers(address) external view returns (address);
    function rewardToken() external view returns (address);
    function setAccumulator(address newAccumulator) external;
    function setDYFIRewardPool(address _dyfiRewardPool) external;
    function setFactory(address _factory) external;
    function setFeeDistributor(address newFeeDistributor) external;
    function setFeeReceiver(address _feeReceiver) external;
    function setFeeRewardToken(address newCurveRewardToken) external;
    function setGauge(address token, address gauge) external;
    function setLGtype(address gauge, uint256 gaugeType) external;
    function setRewardDistributor(
        address gauge,
        address rewardDistributor
    ) external;
    function setRewardReceiver(
        address _gauge,
        address _rewardReceiver
    ) external;
    function setSdtDistributor(address newSdtDistributor) external;
    function toggleVault(address vault) external;
    function transferGovernance(address _governance) external;
    function updateClaimIncentiveFee(uint256 _claimIncentiveFee) external;
    function updateProtocolFee(uint256 protocolFee) external;
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(
        address newImplementation,
        bytes calldata data
    ) external;
    function vaults(address) external view returns (bool);
    function veToken() external view returns (address);
    function withdraw(address asset, uint256 amount) external;
}
