// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

interface IVaultFactory {
    event NewVault(address indexed vault_address, address indexed asset);
    event UpdateProtocolFeeBps(uint16 old_fee_bps, uint16 new_fee_bps);
    event UpdateProtocolFeeRecipient(
        address indexed old_fee_recipient,
        address indexed new_fee_recipient
    );
    event UpdateCustomProtocolFee(
        address indexed vault,
        uint16 new_custom_protocol_fee
    );
    event RemovedCustomProtocolFee(address indexed vault);
    event FactoryShutdown();
    event GovernanceTransferred(
        address indexed previousGovernance,
        address indexed newGovernance
    );
    event UpdatePendingGovernance(address indexed newPendingGovernance);
    function deploy_new_vault(
        address asset,
        string calldata name,
        string calldata symbol,
        address role_manager,
        uint256 profit_max_unlock_time
    ) external returns (address);
    function vault_original() external view returns (address);
    function apiVersion() external view returns (string memory);
    function protocol_fee_config() external view returns (uint16, address);
    function protocol_fee_config(
        address vault
    ) external view returns (uint16, address);
    function use_custom_protocol_fee(
        address vault
    ) external view returns (bool);
    function set_protocol_fee_bps(uint16 new_protocol_fee_bps) external;
    function set_protocol_fee_recipient(
        address new_protocol_fee_recipient
    ) external;
    function set_custom_protocol_fee_bps(
        address vault,
        uint16 new_custom_protocol_fee
    ) external;
    function remove_custom_protocol_fee(address vault) external;
    function shutdown_factory() external;
    function transferGovernance(address new_governance) external;
    function acceptGovernance() external;
    function shutdown() external view returns (bool);
    function governance() external view returns (address);
    function pendingGovernance() external view returns (address);
    function name() external view returns (string memory);
}
