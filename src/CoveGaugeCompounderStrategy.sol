// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {BaseLLGaugeCompounderStrategy} from "./BaseLLGaugeCompounderStrategy.sol";
import {ICoveYearnGaugeFactory} from "./interfaces/cove/ICoveYearnGaugeFactory.sol";
import {IYSDRewardsGauge} from "./interfaces/cove/IYSDRewardsGauge.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title CoveGaugeCompounderStrategy
/// @notice Strategy for compounding rewards from Cove LL gauges
/// @dev Inherits from BaseLLGaugeCompounderStrategy to handle basic LL gauge operations
/// @custom:security-contact security@yearn.fi
contract CoveGaugeCompounderStrategy is BaseLLGaugeCompounderStrategy {
    using SafeERC20 for IERC20;

    ICoveYearnGaugeFactory public constant COVE_GAUGE_FACTORY =
        ICoveYearnGaugeFactory(0x842b22Eb2A1C1c54344eDdbE6959F787c2d15844);

    /// @notice The Cove gauge contract for this strategy
    IYSDRewardsGauge public immutable COVE_GAUGE;

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
            "Cove",
            _assetSwapUniFee,
            _parentVault,
            0x05dcdBF02F29239D1f8d9797E22589A2DE1C152F // Cove YearnStakingDelegate
        )
    {
        COVE_GAUGE = IYSDRewardsGauge(
            COVE_GAUGE_FACTORY
                .yearnGaugeInfoStored(_yGauge)
                .nonAutoCompoundingGauge
        );
        IERC20(vault).safeApprove(_yGauge, type(uint256).max);
        IERC20(_yGauge).safeApprove(address(COVE_GAUGE), type(uint256).max);
    }

    /// @notice Stakes available vault tokens in the Cove gauge
    /// @dev The staking process for Cove follows a two-step sequence:
    ///      1. Deposit vault tokens into Y_GAUGE, receiving Y_GAUGE shares
    ///      2. Deposit those Y_GAUGE shares into COVE_GAUGE
    ///      The actual amount staked depends on what Y_GAUGE.deposit returns, which
    ///      may be less than requested if the gauge has internal limitations.
    function _stake() internal override {
        uint256 _stakeAmount = balanceOfVault();
        _stakeAmount = Y_GAUGE.deposit(_stakeAmount, address(this));
        COVE_GAUGE.deposit(_stakeAmount, address(this));
    }

    /// @notice Unstakes tokens from the Cove gauge
    /// @dev The unstaking process for Cove is the reverse of staking:
    ///      1. Withdraw from COVE_GAUGE first to get Y_GAUGE tokens
    ///      2. Then withdraw from Y_GAUGE to get vault tokens
    ///      This sequence is critical to maintain the proper withdrawal flow and
    ///      ensure tokens are properly unstaked from both gauges.
    /// @param _amount The amount of tokens to unstake
    function _unStake(uint256 _amount) internal override {
        COVE_GAUGE.withdraw(_amount, address(this), address(this));
        Y_GAUGE.withdraw(_amount, address(this), address(this));
    }

    /// @notice Get the current balance of staked tokens
    /// @return The amount of underlying tokens staked in the Cove gauge
    /// @dev Converts gauge shares to underlying asset amount
    function balanceOfStake() public view override returns (uint256) {
        return
            Y_GAUGE.convertToAssets(
                COVE_GAUGE.convertToAssets(COVE_GAUGE.balanceOf(address(this)))
            );
    }

    /// @inheritdoc BaseLLGaugeCompounderStrategy
    function _stakeMaxDeposit() internal view override returns (uint256) {
        return COVE_GAUGE.maxDeposit(address(this));
    }

    /// @notice Claims dYFI rewards from the Cove gauge
    function _claimDYfi() internal override {
        COVE_GAUGE.claimRewards(address(this), address(this));
    }
}
