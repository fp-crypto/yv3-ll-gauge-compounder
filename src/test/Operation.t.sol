// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStrategyInterface, IStrategy} from "./utils/Setup.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {dYFIHelper} from "../libraries/dYFIHelper.sol";
import {IAuction} from "../interfaces/IAuction.sol";

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
        assertTrue(vaultFactory.isDeployedStrategy(address(strategy)));
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

    function test_auction_dYFI(
        IStrategyInterface strategy,
        uint256 _amount,
        uint256 _dyfiRewardAmount
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        ERC20 asset = ERC20(strategy.asset());
        address dYFI = tokenAddrs["dYFI"];
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

        IAuction _auction = IAuction(_createAuction(strategy));

        vm.startPrank(management);
        strategy.setAuction(address(_auction));
        strategy.setUseAuctions(true);
        strategy.setKeepDYfi(true);
        strategy.setKeepWeth(true);
        _auction.enable(dYFI);
        vm.stopPrank();

        skip(10 minutes);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");
        assertGe(
            ERC20(dYFI).balanceOf(address(strategy)),
            _dyfiRewardAmount,
            "dYFI"
        );

        skip(strategy.profitMaxUnlockTime());

        vm.expectRevert();
        strategy.kickAuction(dYFI);

        vm.prank(keeper);
        uint256 kicked = strategy.kickAuction(dYFI);

        assertGe(kicked, _dyfiRewardAmount, "!kicked");
        assertEq(ERC20(dYFI).balanceOf(address(strategy)), 0, "!swap");
        assertEq(asset.balanceOf(address(strategy)), 0, "!asset");
        assertTrue(_auction.isActive(dYFI), "!active");
    }

    function test_auction_weth(
        IStrategyInterface strategy,
        uint256 _amount,
        uint256 _dyfiRewardAmount
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        ERC20 asset = ERC20(strategy.asset());
        address dYFI = tokenAddrs["dYFI"];
        address WETH = tokenAddrs["WETH"];
        vm.assume(address(asset) != WETH);
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

        IAuction _auction = IAuction(_createAuction(strategy));

        vm.startPrank(management);
        strategy.setAuction(address(_auction));
        strategy.setUseAuctions(true);
        strategy.setKeepDYfi(false);
        strategy.setKeepWeth(true);
        _auction.enable(WETH);
        vm.stopPrank();

        skip(10 minutes);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");
        assertEq(ERC20(dYFI).balanceOf(address(strategy)), 0, "dYFI");
        assertGt(ERC20(WETH).balanceOf(address(strategy)), 0, "!WETH");

        skip(strategy.profitMaxUnlockTime());

        vm.expectRevert();
        strategy.kickAuction(WETH);

        vm.prank(keeper);
        uint256 kicked = strategy.kickAuction(WETH);

        assertGt(kicked, 0, "!kicked");
        assertEq(ERC20(WETH).balanceOf(address(strategy)), 0, "!swap");
        assertEq(asset.balanceOf(address(strategy)), 0, "!asset");
        assertTrue(_auction.isActive(WETH), "!active");
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
        bool _keepDYfi,
        bool _keepWeth,
        bool _useAuctions,
        uint24 _wethToAssetSwapFee,
        uint256 _minWethToSwap,
        uint64 _minDYfiToSell
    ) public {
        vm.assume(_isFixtureStrategy(strategy));

        vm.expectRevert("!management");
        strategy.setKeepDYfi(_keepDYfi);
        vm.prank(management);
        strategy.setKeepDYfi(_keepDYfi);
        assertEq(_keepDYfi, strategy.keepDYfi());

        vm.expectRevert("!management");
        strategy.setKeepWeth(_keepWeth);
        vm.prank(management);
        strategy.setKeepWeth(_keepWeth);
        assertEq(_keepWeth, strategy.keepWeth());

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

        vm.expectRevert("!management");
        strategy.setMinDYfiToSell(_minDYfiToSell);
        vm.prank(management);
        strategy.setMinDYfiToSell(_minDYfiToSell);
        assertEq(_minDYfiToSell, strategy.minDYfiToSell());
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

    function test_vaultFactoryUnique(IStrategyInterface strategy) public {
        vm.assume(_isFixtureStrategy(strategy));
        address vault = strategy.vault();
        vm.expectRevert("exists");
        vaultFactory.newLLCompounderVault(vault, "", "", 0);
    }

    function test_dyfi_below_threshold(
        IStrategyInterface strategy,
        uint256 _amount
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        ERC20 asset = ERC20(strategy.asset());
        address dYFI = tokenAddrs["dYFI"];
        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)],
            maxFuzzAmount[address(asset)]
        );

        // Disable health check
        vm.prank(management);
        strategy.setDoHealthCheck(false);

        // Set a minimum dYFI threshold higher than what we'll airdrop
        uint64 threshold = uint64(0.02e18); // 0.02 dYFI
        uint256 smallReward = 0.01e18; // 0.01 dYFI (below threshold)

        vm.prank(management);
        strategy.setMinDYfiToSell(threshold);
        assertEq(threshold, strategy.minDYfiToSell());

        // Set keepDYfi to false to ensure threshold is the deciding factor
        vm.prank(management);
        strategy.setKeepDYfi(false);
        assertEq(false, strategy.keepDYfi());

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);
        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Airdrop a small amount of dYFI (below threshold)
        airdropDYFI(address(strategy), smallReward);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check dYFI was not converted (still in the strategy)
        assertApproxEq(loss, 0, 100);
        assertEq(
            ERC20(dYFI).balanceOf(address(strategy)),
            smallReward,
            "dYFI not kept"
        );

        // Airdrop more dYFI to exceed the threshold
        airdropDYFI(address(strategy), threshold);
        uint256 totalDYfi = smallReward + threshold;

        // Report profit again
        vm.prank(keeper);
        (profit, loss) = strategy.report();

        // Now dYFI should be converted since we're above threshold
        assertEq(loss, 0, "!loss");
        assertEq(
            ERC20(dYFI).balanceOf(address(strategy)),
            0,
            "dYFI should be converted"
        );
    }
}
