// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

/// @title IRegistry
/// @notice Registry for approved gauges
/// @dev Gauges can be added by governance, which makes them eligible
///      to be voted on in the gauge controller.
///      Each registered gauge corresponds to a unique underlying vault.
interface IRegistry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Register(address indexed gauge, uint256 idx);

    event Deregister(address indexed gauge, uint256 idx);

    event UpdateIndex(uint256 indexed old_idx, uint256 idx);

    event SetController(address controller);

    event SetFactory(address factory);

    event PendingManagement(address indexed management);

    event SetManagement(address indexed management);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Current management address
    function management() external view returns (address);

    /// @notice Pending management address
    function pending_management() external view returns (address);

    /// @notice The gauge controller contract
    function controller() external view returns (address);

    /// @notice The gauge factory contract
    function factory() external view returns (address);

    /// @notice Total number of registered vaults
    function vault_count() external view returns (uint256);

    /// @notice Get vault address at a specific index
    /// @param idx Index in the vaults array
    function vaults(uint256 idx) external view returns (address);

    /// @notice Get gauge address for a specific vault
    /// @param vault The vault address
    function vault_gauge_map(address vault) external view returns (address);

    /// @notice Get a gauge at a certain index in the list
    /// @param _idx Index of the gauge
    /// @return Gauge at the specified index
    function gauges(uint256 _idx) external view returns (address);

    /// @notice Check whether a gauge is registered
    /// @param _gauge Gauge address
    /// @return Registration status
    function registered(address _gauge) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                          MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Add a gauge to the registry
    /// @param _gauge Gauge address
    /// @return Index of the vault
    /// @dev Gauge has to originate from the factory
    /// @dev Underlying vault cannot already have a registered gauge
    /// @dev Only callable by management
    function register(address _gauge) external returns (uint256);

    /// @notice Remove a gauge from the registry
    /// @param _gauge Gauge address
    /// @param _idx Vault index
    /// @dev Only callable by management
    function deregister(address _gauge, uint256 _idx) external;

    /// @notice Set a new gauge controller
    /// @param _controller New gauge controller
    /// @dev Only callable by management
    function set_controller(address _controller) external;

    /// @notice Set a new factory
    /// @param _factory New factory
    /// @dev Only callable by management
    function set_factory(address _factory) external;

    /// @notice Set the pending management address
    /// @param _management New pending management address
    function set_management(address _management) external;

    /// @notice Accept management role
    /// @dev Can only be called by account previously marked as pending management
    function accept_management() external;
}
