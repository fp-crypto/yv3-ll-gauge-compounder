// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Liquidity Gauge v4 Interface
 * @author StakeDAO Protocol
 * @notice Interface for StakeDAO's Liquidity Gauge v4 contract
 * @dev Originally forked from Curve Finance's veCRV
 */
interface ILiquidityGauge {
    // Events
    event Deposit(address indexed provider, uint256 value);
    event Withdraw(address indexed provider, uint256 value);
    event UpdateLiquidityLimit(
        address user,
        uint256 original_balance,
        uint256 original_supply,
        uint256 working_balance,
        uint256 working_supply
    );
    event CommitOwnership(address admin);
    event ApplyOwnership(address admin);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );
    event RewardDataUpdate(address indexed _token, uint256 _amount);

    // Structs
    struct Reward {
        address token;
        address distributor;
        uint256 period_finish;
        uint256 rate;
        uint256 last_update;
        uint256 integral;
    }

    // View Functions
    function SDT() external view returns (address);
    function voting_escrow() external view returns (address);
    function veBoost_proxy() external view returns (address);
    function staking_token() external view returns (address);
    function decimal_staking_token() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function working_balances(address account) external view returns (uint256);
    function working_supply() external view returns (uint256);
    function integrate_checkpoint_of(
        address account
    ) external view returns (uint256);
    function reward_count() external view returns (uint256);
    function reward_tokens(uint256 index) external view returns (address);
    function reward_data(address token) external view returns (Reward memory);
    function rewards_receiver(address claimant) external view returns (address);
    function admin() external view returns (address);
    function future_admin() external view returns (address);
    function claimer() external view returns (address);
    function initialized() external view returns (bool);
    function vault() external view returns (address);
    function decimals() external view returns (uint256);

    // State-Changing Functions
    function initialize(
        address _staking_token,
        address _admin,
        address _SDT,
        address _voting_escrow,
        address _veBoost_proxy,
        address _distributor,
        address _vault,
        string memory symbol
    ) external;

    function user_checkpoint(address addr) external returns (bool);

    // Overloaded functions for default arguments
    function deposit(uint256 _value) external;
    function deposit(uint256 _value, address _addr) external;
    function deposit(
        uint256 _value,
        address _addr,
        bool _claim_rewards
    ) external;

    function withdraw(uint256 _value) external;
    function withdraw(uint256 _value, address _addr) external;
    function withdraw(
        uint256 _value,
        address _addr,
        bool _claim_rewards
    ) external;

    function claim_rewards() external;
    function claim_rewards(address _addr) external;
    function claim_rewards(address _addr, address _receiver) external;

    function claim_rewards_for(address _addr, address _receiver) external;

    function kick(address addr) external;
    function set_rewards_receiver(address _receiver) external;
    function set_vault(address _vault) external;

    // ERC20 Functions
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool);
    function approve(address _spender, uint256 _value) external returns (bool);
    function increaseAllowance(
        address _spender,
        uint256 _added_value
    ) external returns (bool);
    function decreaseAllowance(
        address _spender,
        uint256 _subtracted_value
    ) external returns (bool);

    // Reward Management Functions
    function add_reward(address _reward_token, address _distributor) external;
    function set_reward_distributor(
        address _reward_token,
        address _distributor
    ) external;
    function set_claimer(address _claimer) external;
    function deposit_reward_token(
        address _reward_token,
        uint256 _amount
    ) external;

    // View Functions for Rewards
    function claimed_reward(
        address _addr,
        address _token
    ) external view returns (uint256);
    function claimable_reward(
        address _user,
        address _reward_token
    ) external view returns (uint256);

    // Admin Functions
    function commit_transfer_ownership(address addr) external;
    function accept_transfer_ownership() external;
}
