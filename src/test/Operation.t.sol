// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";
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
        assertEq(strategy.asset(), address(asset));
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
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);

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
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);
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
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);
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
        _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);
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

    // function test_profitableReportBaseThenAirdrop(
    //     uint256 _amount,
    //     uint256 _dyfiRewardAmount
    // ) public {
    //     _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);
    //     _dyfiRewardAmount = bound(
    //         _dyfiRewardAmount,
    //         (strategy.minAmountToSell() * 10) / 2,
    //         Math.min(_amount / 10, maxDYFI()) // airdrop no more than 10% of the strategy value
    //     );

    //     // Deposit into strategy
    //     mintAndDepositIntoStrategy(strategy, user, _amount);

    //     assertEq(strategy.totalAssets(), _amount, "!totalAssets");

    //     // Earn Interest
    //     skip(1 days);

    //     // Report profit
    //     vm.prank(keeper);
    //     (uint256 profit, uint256 loss) = strategy.report();

    //     // Check return Values
    //     assertGt(profit, 0, "!profit");
    //     assertEq(loss, 0, "!loss");

    //     skip(strategy.profitMaxUnlockTime());

    //     airdropDYFI(address(strategy), _dyfiRewardAmount);

    //     // Report profit
    //     vm.prank(keeper);
    //     (profit, loss) = strategy.report();

    //     // Check return Values
    //     assertGt(profit, 0, "!profit");
    //     assertEq(loss, 0, "!loss");

    //     skip(strategy.profitMaxUnlockTime());

    //     uint256 balanceBefore = asset.balanceOf(user);

    //     // Withdraw all funds
    //     vm.prank(user);
    //     strategy.redeem(_amount, user, user);

    //     assertGe(
    //         asset.balanceOf(user),
    //         balanceBefore + _amount,
    //         "!final balance"
    //     );
    // }

    // function test_profitableReportAirdropThenBase(
    //     uint256 _amount,
    //     uint256 _dyfiRewardAmount
    // ) public {
    //     _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);
    //     _dyfiRewardAmount = bound(
    //         _dyfiRewardAmount,
    //         (strategy.minAmountToSell() * 10) / 2,
    //         Math.min(_amount / 10, maxDYFI()) // airdrop no more than 10% of the strategy value
    //     );

    //     // Deposit into strategy
    //     mintAndDepositIntoStrategy(strategy, user, _amount);

    //     assertEq(strategy.totalAssets(), _amount, "!totalAssets");

    //     airdropDYFI(address(strategy), _dyfiRewardAmount);

    //     // Report profit
    //     vm.prank(keeper);
    //     (uint256 profit, uint256 loss) = strategy.report();

    //     // Check return Values
    //     assertGt(profit, 0, "!profit");
    //     assertEq(loss, 0, "!loss");

    //     skip(strategy.profitMaxUnlockTime());

    //     // Report profit
    //     vm.prank(keeper);
    //     (profit, loss) = strategy.report();

    //     // Check return Values
    //     assertGt(profit, 0, "!profit");
    //     assertEq(loss, 0, "!loss");

    //     skip(strategy.profitMaxUnlockTime());

    //     uint256 balanceBefore = asset.balanceOf(user);

    //     // Withdraw all funds
    //     vm.prank(user);
    //     strategy.redeem(_amount, user, user);

    //     assertGe(
    //         asset.balanceOf(user),
    //         balanceBefore + _amount,
    //         "!final balance"
    //     );
    // }

    // function test_profitableReportAirdropThenBase_DudesVersion(
    //     uint256 _amount
    // ) public {
    //     _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);
    //     uint256 _dyfiRewardAmount = Math.min(_amount / 10, maxDYFI()); // airdrop no more than 10% of the strategy value

    //     // Deposit into strategy
    //     mintAndDepositIntoStrategy(strategy, user, _amount);

    //     assertEq(strategy.totalAssets(), _amount, "!totalAssets");

    //     skip(strategy.profitMaxUnlockTime());
    //     airdropDYFI(address(strategy), _dyfiRewardAmount);

    //     // Report profit
    //     vm.prank(keeper);
    //     (uint256 profitWithAirdrop, uint256 loss) = strategy.report();

    //     // Check return Values
    //     assertGt(profitWithAirdrop, 0, "!profit");
    //     assertEq(loss, 0, "!loss");

    //     skip(strategy.profitMaxUnlockTime());

    //     uint256 profit;
    //     // Report profit
    //     vm.prank(keeper);
    //     (profit, loss) = strategy.report();

    //     // Check return Values
    //     assertGt(profit, 0, "!profit");
    //     assertEq(loss, 0, "!loss");
    //     assertGt(profitWithAirdrop, profit, "!airdropProfit");

    //     skip(strategy.profitMaxUnlockTime());

    //     uint256 balanceBefore = asset.balanceOf(user);

    //     // Withdraw all funds
    //     vm.prank(user);
    //     strategy.redeem(_amount, user, user);

    //     assertGe(
    //         asset.balanceOf(user),
    //         balanceBefore + _amount,
    //         "!final balance"
    //     );
    // }

    // function test_profitableReportOnlyBase(uint256 _amount) public {
    //     _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);

    //     // Deposit into strategy
    //     mintAndDepositIntoStrategy(strategy, user, _amount);

    //     assertEq(strategy.totalAssets(), _amount, "!totalAssets");

    //     skip(1 days);

    //     // Report profit
    //     vm.prank(keeper);
    //     (uint256 profit, uint256 loss) = strategy.report();

    //     // Check return Values
    //     assertGt(profit, 0, "!profit");
    //     assertEq(loss, 0, "!loss");

    //     skip(strategy.profitMaxUnlockTime());

    //     uint256 balanceBefore = asset.balanceOf(user);

    //     // Withdraw all funds
    //     vm.prank(user);
    //     strategy.redeem(_amount, user, user);

    //     assertGe(
    //         asset.balanceOf(user),
    //         balanceBefore + _amount,
    //         "!final balance"
    //     );
    // }

    // function test_profitableReportOnlyAirdrop(
    //     uint256 _amount,
    //     uint256 _dyfiRewardAmount
    // ) public {
    //     _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);
    //     _dyfiRewardAmount = bound(
    //         _dyfiRewardAmount,
    //         (strategy.minAmountToSell() * 10) / 2,
    //         Math.min(_amount / 10, maxDYFI()) // airdrop no more than 10% of the strategy value
    //     );

    //     // Deposit into strategy
    //     mintAndDepositIntoStrategy(strategy, user, _amount);

    //     assertEq(strategy.totalAssets(), _amount, "!totalAssets");

    //     airdropDYFI(address(strategy), _dyfiRewardAmount);

    //     // Report profit
    //     vm.prank(keeper);
    //     (uint256 profit, uint256 loss) = strategy.report();

    //     // Check return Values
    //     assertGt(profit, 0, "!profit");
    //     assertEq(loss, 0, "!loss");

    //     skip(strategy.profitMaxUnlockTime());

    //     uint256 balanceBefore = asset.balanceOf(user);

    //     // Withdraw all funds
    //     vm.prank(user);
    //     strategy.redeem(_amount, user, user);

    //     assertGe(
    //         asset.balanceOf(user),
    //         balanceBefore + _amount,
    //         "!final balance"
    //     );
    // }

    // // function test_setters(
    // //     uint96 _minEulToSwap,
    // //     uint24 _eulToWethSwapFee,
    // //     uint24 _wethToAssetSwapFee
    // // ) public {
    // //     vm.expectRevert("!management");
    // //     strategy.setMinEulToSwap(uint256(_minEulToSwap));
    // //     vm.prank(management);
    // //     strategy.setMinEulToSwap(uint256(_minEulToSwap));
    // //     assertEq(uint256(_minEulToSwap), strategy.minAmountToSell());

    // //     vm.expectRevert("!management");
    // //     strategy.setEulToWethSwapFee(_eulToWethSwapFee);
    // //     vm.prank(management);
    // //     strategy.setEulToWethSwapFee(_eulToWethSwapFee);
    // //     assertEq(
    // //         _eulToWethSwapFee,
    // //         strategy.uniFees(strategy.EUL(), strategy.WETH())
    // //     );

    // //     vm.expectRevert("!management");
    // //     strategy.setWethToAssetSwapFee(_wethToAssetSwapFee);
    // //     vm.prank(management);
    // //     strategy.setWethToAssetSwapFee(_wethToAssetSwapFee);
    // //     assertEq(
    // //         _wethToAssetSwapFee,
    // //         strategy.uniFees(strategy.WETH(), strategy.asset())
    // //     );
    // // }

    // function test_tendTrigger(uint256 _amount) public {
    //     _amount = bound(_amount, minFuzzAmount, maxFuzzAmount);

    //     (bool trigger, ) = strategy.tendTrigger();
    //     assertTrue(!trigger);

    //     // Deposit into strategy
    //     mintAndDepositIntoStrategy(strategy, user, _amount);

    //     (trigger, ) = strategy.tendTrigger();
    //     assertTrue(!trigger);

    //     // Skip some time
    //     skip(1 days);

    //     (trigger, ) = strategy.tendTrigger();
    //     assertTrue(!trigger);

    //     vm.prank(keeper);
    //     strategy.report();

    //     (trigger, ) = strategy.tendTrigger();
    //     assertTrue(!trigger);

    //     // Unlock Profits
    //     skip(strategy.profitMaxUnlockTime());

    //     (trigger, ) = strategy.tendTrigger();
    //     assertTrue(!trigger);

    //     vm.prank(user);
    //     strategy.redeem(_amount, user, user);

    //     (trigger, ) = strategy.tendTrigger();
    //     assertTrue(!trigger);
    // }

    // function test_strategyFactoryUnique() public {
    //     address vault = strategy.vault();
    //     vm.expectRevert("exists");
    //     strategyFactory.newStrategy(vault, "", 0);
    // }
}
