// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

/// @title IRegistry
/// @notice Interface for tracking registered protocol gauges and underlying Yearn gauges
/// @dev A Yearn gauge can have at most one protocol gauge in the registry
interface IRegistry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Register(address indexed gauge, address indexed ygauge, uint256 idx);

    event Deregister(
        address indexed gauge,
        address indexed ygauge,
        uint256 indexed idx
    );

    event NewIndex(uint256 indexed old_idx, uint256 new_idx);

    event Disable(address indexed ygauge, bool disabled);

    event SetRegistrar(address registrar);
    event PendingManagement(address management);
    event SetManagement(address management);

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum number of gauges that can be registered
    function MAX_NUM_GAUGES() external pure returns (uint256);

    /// @notice Special address used to mark disabled Yearn gauges
    function YGAUGE_DISABLED() external pure returns (address);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the proxy contract address
    function proxy() external view returns (address);

    /// @notice Get the current management address
    function management() external view returns (address);

    /// @notice Get the pending management address
    function pending_management() external view returns (address);

    /// @notice Get the current registrar address
    function registrar() external view returns (address);

    /// @notice Get the total number of registered gauges
    function num_gauges() external view returns (uint256);

    /// @notice Get the Yearn gauge address at a specific index
    function ygauges(uint256 _idx) external view returns (address);

    /// @notice Get the protocol gauge address for a Yearn gauge
    function gauge_map(address _ygauge) external view returns (address);

    /// @notice Get the protocol gauge at a specific index
    function gauges(uint256 _idx) external view returns (address);

    /// @notice Check if a protocol gauge is registered
    function gauge_registered(address _gauge) external view returns (bool);

    /// @notice Check if a Yearn gauge is registered
    function ygauge_registered(address _ygauge) external view returns (bool);

    /// @notice Check if a Yearn gauge is disabled
    function disabled(address _ygauge) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                          MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Register a new gauge
    /// @param _gauge Protocol gauge address to register
    /// @return Index of the newly registered gauge
    function register(address _gauge) external returns (uint256);

    /// @notice Deregister an existing gauge
    /// @param _gauge Protocol gauge address to deregister
    /// @param _idx Index of the gauge to deregister
    function deregister(address _gauge, uint256 _idx) external;

    /// @notice Disable or enable a Yearn gauge
    /// @param _ygauge Yearn gauge address
    /// @param _disabled True to disable, false to enable
    function disable(address _ygauge, bool _disabled) external;

    /// @notice Set a new registrar address
    /// @param _registrar New registrar address
    function set_registrar(address _registrar) external;

    /// @notice Set pending management address
    /// @param _management New pending management address
    function set_management(address _management) external;

    /// @notice Accept management role
    function accept_management() external;
}
