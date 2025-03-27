// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {BaseLLGaugeCompounderStrategy} from "./BaseLLGaugeCompounderStrategy.sol";
import {IYearnStrategy as IStakeDaoYearnStrategy} from "./interfaces/stakedao/IYearnStrategy.sol";
import {ILiquidityGauge} from "./interfaces/stakedao/ILiquidityGauge.sol";
import {IGaugeDepositorVault} from "./interfaces/stakedao/IGaugeDepositorVault.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title StakeDaoGaugeCompounderStrategy
/// @notice Strategy for compounding rewards from StakeDAO LL gauges
/// @dev Inherits from BaseLLGaugeCompounderStrategy to handle basic LL gauge operations
/// @custom:security-contact security@yearn.fi
contract StakeDaoGaugeCompounderStrategy is BaseLLGaugeCompounderStrategy {
    using SafeERC20 for IERC20;

    IStakeDaoYearnStrategy public constant STAKE_DAO_YEARN_STRATEGY =
        IStakeDaoYearnStrategy(0x1be150a35bb8233d092747eBFDc75FB357c35168);

    IGaugeDepositorVault public immutable STAKE_DAO_GAUGE_DEPOSITOR_VAULT;
    ILiquidityGauge public immutable STAKE_DAO_LIQUIDITY_GAUGE;

    /// @notice Initialize the strategy with a gauge and name
    /// @param _yGauge The Yearn gauge address this strategy will compound
    /// @param _assetSwapUniFee The Uniswap V3 fee tier for asset swaps
    /// @param _parentVault Address of the parent allocator vault that distributes funds between LL strategies
    constructor(
        address _yGauge,
        uint24 _assetSwapUniFee,
        address _parentVault
    )
        BaseLLGaugeCompounderStrategy(
            _yGauge,
            "StakeDao",
            _assetSwapUniFee,
            _parentVault
        )
    {
        STAKE_DAO_LIQUIDITY_GAUGE = ILiquidityGauge(
            STAKE_DAO_YEARN_STRATEGY.rewardDistributors(_yGauge)
        );
        STAKE_DAO_GAUGE_DEPOSITOR_VAULT = IGaugeDepositorVault(
            STAKE_DAO_LIQUIDITY_GAUGE.vault()
        );

        IERC20(vault).safeApprove(
            address(STAKE_DAO_GAUGE_DEPOSITOR_VAULT),
            type(uint256).max
        );
    }

    /// @notice Calculate the maximum amount that can be withdrawn from all vaults
    /// @return The maximum withdrawable amount in terms of the underlying asset
    /// @dev Combines the withdrawable amounts from both the vault and the gauge
    function vaultsMaxWithdraw() public view override returns (uint256) {
        return
            vault.convertToAssets(
                vault.maxRedeem(address(this)) +
                    STAKE_DAO_LIQUIDITY_GAUGE.balanceOf(address(this))
            );
    }

    /// @notice Stakes available vault tokens in the StakeDAO gauge
    /// @dev Stakes the minimum of available balance and max deposit allowed
    function _stake() internal override {
        STAKE_DAO_GAUGE_DEPOSITOR_VAULT.deposit(
            address(this),
            balanceOfVault(),
            true
        );
    }

    /// @notice Unstakes tokens from the StakeDAO gauge
    /// @param _amount The amount of tokens to unstake
    /// @dev Withdraws directly to this contract's address
    function _unStake(uint256 _amount) internal override {
        STAKE_DAO_GAUGE_DEPOSITOR_VAULT.withdraw(_amount);
    }

    /// @notice Get the current balance of staked tokens
    /// @return The amount of underlying tokens staked in the StakeDAO gauge
    /// @dev Converts gauge shares to underlying asset amount
    function balanceOfStake() public view override returns (uint256) {
        return STAKE_DAO_LIQUIDITY_GAUGE.balanceOf(address(this));
    }

    /// @notice Claims dYFI rewards from the StakeDAO gauge
    function _claimDYfi() internal override {
        STAKE_DAO_LIQUIDITY_GAUGE.claim_rewards(address(this), address(this));
    }
}
