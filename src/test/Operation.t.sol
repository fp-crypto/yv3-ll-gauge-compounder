// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStrategyInterface, IStrategy} from "./utils/Setup.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {dYFIHelper} from "../libraries/dYFIHelper.sol";

contract OperationTest is Setup {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_setupStrategyOK(IStrategyInterface strategy) public {
        vm.assume(_isFixtureStrategy(strategy));

        console2.log("address of strategy", address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(strategy.asset(), IStrategy(strategy.vault()).asset());
        assertEq(strategy.management(), management);
        assertEq(strategy.performanceFeeRecipient(), performanceFeeRecipient);
        assertEq(strategy.keeper(), keeper);
        assertTrue(strategyFactory.isDeployedStrategy(address(strategy)));
    }

    function test_operation(
        IStrategyInterface strategy,
        uint256 _amount
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        ERC20 asset = ERC20(strategy.asset());
        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)],
            maxFuzzAmount[address(asset)]
        );

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        skip(10 minutes);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_profitableReport_airdrop(
        IStrategyInterface strategy,
        uint256 _amount,
        uint256 _dyfiRewardAmount
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        ERC20 asset = ERC20(strategy.asset());
        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)],
            maxFuzzAmount[address(asset)]
        );
        _dyfiRewardAmount = bound(
            _dyfiRewardAmount,
            strategy.minAmountToSell(),
            Math.max(
                Math.min(_amount / 500, maxDYFI()),
                strategy.minAmountToSell() + 1
            ) // airdrop no more than 0.5% of the strategy value
        );

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        airdropDYFI(address(strategy), _dyfiRewardAmount);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGt(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_profitableReport_airdrop_forceRedeem(
        IStrategyInterface strategy,
        uint256 _amount,
        uint256 _dyfiRewardAmount
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        ERC20 asset = ERC20(strategy.asset());
        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)],
            maxFuzzAmount[address(asset)]
        );
        _dyfiRewardAmount = bound(
            _dyfiRewardAmount,
            strategy.minAmountToSell(),
            Math.max(
                Math.min(_amount / 500, maxDYFI()),
                strategy.minAmountToSell() + 1
            ) // airdrop no more than 0.5% of the strategy value
        );

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        airdropDYFI(address(strategy), _dyfiRewardAmount);

        vm.mockCall(
            address(dYFIHelper.CURVE_DYFI_ETH),
            dYFIHelper.CURVE_DYFI_ETH.get_dy.selector,
            abi.encode(0)
        );

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGt(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_profitableReport_airdrop_forceCurveOnly(
        IStrategyInterface strategy,
        uint256 _amount,
        uint256 _dyfiRewardAmount
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        ERC20 asset = ERC20(strategy.asset());
        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)],
            maxFuzzAmount[address(asset)]
        );
        _dyfiRewardAmount = bound(
            _dyfiRewardAmount,
            strategy.minAmountToSell(),
            Math.max(
                Math.min(_amount / 500, maxDYFI()),
                strategy.minAmountToSell() + 1
            ) // airdrop no more than 0.5% of the strategy value
        );

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        airdropDYFI(address(strategy), _dyfiRewardAmount);

        vm.mockCall(
            address(dYFIHelper.CURVE_YFI_ETH),
            dYFIHelper.CURVE_YFI_ETH.get_dy.selector,
            abi.encode(0)
        );

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGt(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_profitableReport_forceCurveOnly(
        IStrategyInterface strategy,
        uint256 _amount
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        ERC20 asset = ERC20(strategy.asset());
        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)],
            maxFuzzAmount[address(asset)]
        );

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        skip(1 weeks);

        vm.mockCall(
            address(dYFIHelper.DYFI_REDEEMER),
            dYFIHelper.DYFI_REDEEMER.eth_required.selector,
            abi.encode(type(uint256).max)
        );

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGt(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_setters(
        IStrategyInterface strategy,
        bool _dontDumpDYfi,
        bool _dontSwapWeth,
        bool _useAuctions,
        uint24 _wethToAssetSwapFee,
        uint256 _minWethToSwap
    ) public {
        vm.assume(_isFixtureStrategy(strategy));

        vm.expectRevert("!management");
        strategy.setDontDumpDYfi(_dontDumpDYfi);
        vm.prank(management);
        strategy.setDontDumpDYfi(_dontDumpDYfi);
        assertEq(_dontDumpDYfi, strategy.dontDumpDYfi());

        vm.expectRevert("!management");
        strategy.setDontSwapWeth(_dontSwapWeth);
        vm.prank(management);
        strategy.setDontSwapWeth(_dontSwapWeth);
        assertEq(_dontSwapWeth, strategy.dontSwapWeth());

        vm.expectRevert("!management");
        strategy.setUseAuctions(_useAuctions);
        vm.prank(management);
        strategy.setUseAuctions(_useAuctions);
        assertEq(_useAuctions, strategy.useAuctions());

        vm.expectRevert("!management");
        strategy.setWethToAssetSwapFee(_wethToAssetSwapFee);
        vm.prank(management);
        strategy.setWethToAssetSwapFee(_wethToAssetSwapFee);
        assertEq(
            _wethToAssetSwapFee,
            strategy.uniFees(strategy.WETH(), strategy.asset())
        );
        assertEq(
            _wethToAssetSwapFee,
            strategy.uniFees(strategy.asset(), strategy.WETH())
        );

        vm.expectRevert("!management");
        strategy.setMinWethToSwap(_minWethToSwap);
        vm.prank(management);
        strategy.setMinWethToSwap(_minWethToSwap);
        assertEq(_minWethToSwap, strategy.minAmountToSell());
    }

    function test_tendTrigger(
        IStrategyInterface strategy,
        uint256 _amount
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        ERC20 asset = ERC20(strategy.asset());
        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)],
            maxFuzzAmount[address(asset)]
        );

        (bool trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Skip some time
        skip(10 minutes);

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        vm.prank(keeper);
        strategy.report();

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Unlock Profits
        skip(strategy.profitMaxUnlockTime());

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        vm.prank(user);
        strategy.redeem(_amount, user, user);

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);
    }

    function test_strategyFactoryUnique(IStrategyInterface strategy) public {
        vm.assume(_isFixtureStrategy(strategy));
        address vault = strategy.vault();
        vm.expectRevert("exists");
        strategyFactory.newStrategiesGroup(vault, "", 0);
    }
}
