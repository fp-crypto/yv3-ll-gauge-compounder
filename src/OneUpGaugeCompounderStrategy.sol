// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {BaseLLGaugeCompounderStrategy} from "./BaseLLGaugeCompounderStrategy.sol";
import {IGauge as IOneUpGauge} from "./interfaces/1up/IGauge.sol";
import {IGaugeRewards as IOneUpGaugeRewards} from "./interfaces/1up/IGaugeRewards.sol";
import {IRegistry} from "./interfaces/1up/IRegistry.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title OneUpGaugeCompounderStrategy
/// @notice Strategy for compounding rewards from 1UP LL gauges
/// @dev Inherits from BaseLLGaugeCompounderStrategy to handle basic LL gauge operations
/// @custom:security-contact security@yearn.fi
contract OneUpGaugeCompounderStrategy is BaseLLGaugeCompounderStrategy {
    using SafeERC20 for IERC20;

    /// @notice The 1UP registry contract that tracks all gauges
    IRegistry public constant ONE_UP_REGISTRY =
        IRegistry(0x512AdCb1e162bf447919D46Ae5B42d9331e9DF5D);

    /// @notice The 1UP gauge contract for this strategy
    IOneUpGauge public immutable ONE_UP_GAUGE;

    /// @notice The rewards contract for the 1UP gauge
    IOneUpGaugeRewards public immutable ONE_UP_GAUGE_REWARDS;

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
            "1up",
            _assetSwapUniFee,
            _parentVault,
            0x242521ca01f330F050a65FF5B8Ebbe92198Ae64F // 1up Proxy
        )
    {
        ONE_UP_GAUGE = IOneUpGauge(ONE_UP_REGISTRY.gauge_map(_yGauge));
        ONE_UP_GAUGE_REWARDS = IOneUpGaugeRewards(ONE_UP_GAUGE.rewards());

        IERC20(vault).safeApprove(address(ONE_UP_GAUGE), type(uint256).max);
    }

    /// @notice Stakes available vault tokens in the 1UP gauge
    /// @dev Stakes the minimum of available balance and max deposit allowed
    function _stake() internal override {
        uint256 _stakeAmount = Math.min(
            balanceOfVault(),
            ONE_UP_GAUGE.maxDeposit(address(this))
        );
        ONE_UP_GAUGE.deposit(_stakeAmount, address(this));
    }

    /// @notice Unstakes tokens from the 1UP gauge
    /// @param _amount The amount of tokens to unstake
    /// @dev Withdraws directly to this contract's address
    function _unStake(uint256 _amount) internal override {
        ONE_UP_GAUGE.withdraw(_amount, address(this), address(this));
    }

    /// @notice Get the current balance of staked tokens
    /// @return The amount of underlying tokens staked in the 1UP gauge
    /// @dev Converts gauge shares to underlying asset amount
    function balanceOfStake() public view override returns (uint256) {
        return
            Y_GAUGE.convertToAssets(
                ONE_UP_GAUGE.convertToAssets(
                    ONE_UP_GAUGE.balanceOf(address(this))
                )
            );
    }

    /// @notice Claims dYFI rewards from the 1UP gauge
    function _claimDYfi() internal override {
        address[] memory _gauges = new address[](1);
        _gauges[0] = address(ONE_UP_GAUGE);
        ONE_UP_GAUGE_REWARDS.claim(_gauges, address(this));
    }
}
