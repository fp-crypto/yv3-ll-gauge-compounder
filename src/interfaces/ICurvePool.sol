// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ICurvePool {
    // Overloaded exchange functions
    /// @notice Exchange tokens using WETH by default.
    /// @param i Index of the input token.
    /// @param j Index of the output token.
    /// @param dx Amount of input tokens to exchange.
    /// @param min_dy Minimum amount of output tokens to receive.
    /// @return Amount of output tokens received.
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy
    ) external payable returns (uint256);

    /// @notice Exchange tokens using WETH by default.
    /// @param i Index of the input token.
    /// @param j Index of the output token.
    /// @param dx Amount of input tokens to exchange.
    /// @param min_dy Minimum amount of output tokens to receive.
    /// @param use_eth Whether to use ETH for the transaction.
    /// @return Amount of output tokens received.
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy,
        bool use_eth
    ) external payable returns (uint256);

    /// @notice Exchange tokens using WETH by default.
    /// @param i Index of the input token.
    /// @param j Index of the output token.
    /// @param dx Amount of input tokens to exchange.
    /// @param min_dy Minimum amount of output tokens to receive.
    /// @param use_eth Whether to use ETH for the transaction.
    /// @param receiver Address to receive the output tokens.
    /// @return Amount of output tokens received.
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy,
        bool use_eth,
        address receiver
    ) external payable returns (uint256);

    // Overloaded exchange_underlying functions
    /// @notice Exchange tokens using ETH.
    /// @param i Index of the input token.
    /// @param j Index of the output token.
    /// @param dx Amount of input tokens to exchange.
    /// @param min_dy Minimum amount of output tokens to receive.
    /// @return Amount of output tokens received.
    function exchange_underlying(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy
    ) external payable returns (uint256);

    /// @notice Exchange tokens using ETH.
    /// @param i Index of the input token.
    /// @param j Index of the output token.
    /// @param dx Amount of input tokens to exchange.
    /// @param min_dy Minimum amount of output tokens to receive.
    /// @param receiver Address to receive the output tokens.
    /// @return Amount of output tokens received.
    function exchange_underlying(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy,
        address receiver
    ) external payable returns (uint256);

    // Overloaded add_liquidity functions
    /// @notice Add liquidity to the pool.
    /// @param amounts Amounts of tokens to add.
    /// @param min_mint_amount Minimum amount of LP tokens to mint.
    /// @return Amount of LP tokens minted.
    function add_liquidity(
        uint256[2] memory amounts,
        uint256 min_mint_amount
    ) external payable returns (uint256);

    /// @notice Add liquidity to the pool.
    /// @param amounts Amounts of tokens to add.
    /// @param min_mint_amount Minimum amount of LP tokens to mint.
    /// @param use_eth Whether to use ETH for the transaction.
    /// @return Amount of LP tokens minted.
    function add_liquidity(
        uint256[2] memory amounts,
        uint256 min_mint_amount,
        bool use_eth
    ) external payable returns (uint256);

    /// @notice Add liquidity to the pool.
    /// @param amounts Amounts of tokens to add.
    /// @param min_mint_amount Minimum amount of LP tokens to mint.
    /// @param use_eth Whether to use ETH for the transaction.
    /// @param receiver Address to receive the LP tokens.
    /// @return Amount of LP tokens minted.
    function add_liquidity(
        uint256[2] memory amounts,
        uint256 min_mint_amount,
        bool use_eth,
        address receiver
    ) external payable returns (uint256);

    // Overloaded remove_liquidity functions
    /// @notice Remove liquidity from the pool.
    /// @param _amount Amount of LP tokens to burn.
    /// @param min_amounts Minimum amounts of tokens to receive.
    function remove_liquidity(
        uint256 _amount,
        uint256[2] memory min_amounts
    ) external;

    /// @notice Remove liquidity from the pool.
    /// @param _amount Amount of LP tokens to burn.
    /// @param min_amounts Minimum amounts of tokens to receive.
    /// @param use_eth Whether to use ETH for the transaction.
    function remove_liquidity(
        uint256 _amount,
        uint256[2] memory min_amounts,
        bool use_eth
    ) external;

    /// @notice Remove liquidity from the pool.
    /// @param _amount Amount of LP tokens to burn.
    /// @param min_amounts Minimum amounts of tokens to receive.
    /// @param use_eth Whether to use ETH for the transaction.
    /// @param receiver Address to receive the tokens.
    function remove_liquidity(
        uint256 _amount,
        uint256[2] memory min_amounts,
        bool use_eth,
        address receiver
    ) external;

    // Overloaded remove_liquidity_one_coin functions
    /// @notice Remove liquidity for a single coin.
    /// @param token_amount Amount of LP tokens to burn.
    /// @param i Index of the coin to withdraw.
    /// @param min_amount Minimum amount of the coin to receive.
    /// @return Amount of the coin received.
    function remove_liquidity_one_coin(
        uint256 token_amount,
        uint256 i,
        uint256 min_amount
    ) external returns (uint256);

    /// @notice Remove liquidity for a single coin.
    /// @param token_amount Amount of LP tokens to burn.
    /// @param i Index of the coin to withdraw.
    /// @param min_amount Minimum amount of the coin to receive.
    /// @param use_eth Whether to use ETH for the transaction.
    /// @return Amount of the coin received.
    function remove_liquidity_one_coin(
        uint256 token_amount,
        uint256 i,
        uint256 min_amount,
        bool use_eth
    ) external returns (uint256);

    /// @notice Remove liquidity for a single coin.
    /// @param token_amount Amount of LP tokens to burn.
    /// @param i Index of the coin to withdraw.
    /// @param min_amount Minimum amount of the coin to receive.
    /// @param use_eth Whether to use ETH for the transaction.
    /// @param receiver Address to receive the coin.
    /// @return Amount of the coin received.
    function remove_liquidity_one_coin(
        uint256 token_amount,
        uint256 i,
        uint256 min_amount,
        bool use_eth,
        address receiver
    ) external returns (uint256);

    /// @notice Claim admin fees.
    function claim_admin_fees() external;

    /// @notice Start ramping of A and gamma parameters.
    /// @param future_A Future value of A.
    /// @param future_gamma Future value of gamma.
    /// @param future_time Timestamp when the ramp ends.
    function ramp_A_gamma(
        uint256 future_A,
        uint256 future_gamma,
        uint256 future_time
    ) external;

    /// @notice Stop ramping of A and gamma parameters.
    function stop_ramp_A_gamma() external;

    /// @notice Commit new parameters for the pool.
    /// @param _new_mid_fee New mid fee.
    /// @param _new_out_fee New out fee.
    /// @param _new_admin_fee New admin fee.
    /// @param _new_fee_gamma New fee gamma.
    /// @param _new_allowed_extra_profit New allowed extra profit.
    /// @param _new_adjustment_step New adjustment step.
    /// @param _new_ma_half_time New moving average half time.
    function commit_new_parameters(
        uint256 _new_mid_fee,
        uint256 _new_out_fee,
        uint256 _new_admin_fee,
        uint256 _new_fee_gamma,
        uint256 _new_allowed_extra_profit,
        uint256 _new_adjustment_step,
        uint256 _new_ma_half_time
    ) external;

    /// @notice Apply new parameters for the pool.
    function apply_new_parameters() external;

    /// @notice Revert new parameters for the pool.
    function revert_new_parameters() external;

    /// @notice Get the amount of output tokens for a given input.
    /// @param i Index of the input token.
    /// @param j Index of the output token.
    /// @param dx Amount of input tokens.
    /// @return Amount of output tokens.
    function get_dy(
        uint256 i,
        uint256 j,
        uint256 dx
    ) external view returns (uint256);

    /// @notice Calculate the amount of LP tokens to mint for given amounts of tokens.
    /// @param amounts Amounts of tokens to add.
    /// @return Amount of LP tokens to mint.
    function calc_token_amount(
        uint256[2] memory amounts
    ) external view returns (uint256);

    /// @notice Calculate the amount of a single coin to withdraw.
    /// @param token_amount Amount of LP tokens to burn.
    /// @param i Index of the coin to withdraw.
    /// @return Amount of the coin to receive.
    function calc_withdraw_one_coin(
        uint256 token_amount,
        uint256 i
    ) external view returns (uint256);

    /// @notice Get the approximate LP token price.
    /// @return Approximate LP token price.
    function lp_price() external view returns (uint256);

    /// @notice Get the current value of A.
    /// @return Current value of A.
    function A() external view returns (uint256);

    /// @notice Get the current value of gamma.
    /// @return Current value of gamma.
    function gamma() external view returns (uint256);

    /// @notice Get the current fee.
    /// @return Current fee.
    function fee() external view returns (uint256);

    /// @notice Get the virtual price of the pool.
    /// @return Virtual price of the pool.
    function get_virtual_price() external view returns (uint256);

    /// @notice Get the price oracle value.
    /// @return Price oracle value.
    function price_oracle() external view returns (uint256);
}
