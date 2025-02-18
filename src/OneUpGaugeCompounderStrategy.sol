// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {BaseLLGaugeCompounderStrategy, IStrategy} from "./BaseLLGaugeCompounderStrategy.sol";
import {IGauge} from "./interfaces/1up/IGauge.sol";
import {IGaugeRewards} from "./interfaces/1up/IGaugeRewards.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OneUpGaugeCompounderStrategy is BaseLLGaugeCompounderStrategy {
    using SafeERC20 for IERC20;

    IGauge public immutable ONE_UP_GAUGE;
    IGaugeRewards public immutable ONE_UP_GAUGE_REWARDS;

    constructor(
        address _vault,
        string memory _name,
        uint24 _assetSwapUniFee,
        address _oneUpGauge
    ) BaseLLGaugeCompounderStrategy(_vault, _name, _assetSwapUniFee) {
        ONE_UP_GAUGE = IGauge(_oneUpGauge);
        ONE_UP_GAUGE_REWARDS = IGaugeRewards(IGauge(_oneUpGauge).rewards());

        IERC20(_vault).approve(address(ONE_UP_GAUGE), type(uint256.max));
    }

    function _stake() internal override {
        uint256 _stakeAmount = Math.min(
            balanceOfVault(),
            ONE_UP_GAUGE.maxDeposit(address(this))
        );
        ONE_UP_GAUGE.deposit(_stakeAmount, address(this));
    }


    function _unStake(uint256 _amount) internal override {
        ONE_UP_GAUGE.withdraw(_amount, address(this), address(this));
    }


    function _claimDYfi() internal override {
        address[] _gauges = new address[](1);
        _gauges[0] = address(ONE_UP_GAUGE);
        ONE_UP_GAUGE_REWARDS.claim(_gauges, address(this));
    }
}
