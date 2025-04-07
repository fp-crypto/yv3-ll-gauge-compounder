// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStrategyInterface, IStrategy} from "./utils/Setup.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {dYFIHelper} from "../libraries/dYFIHelper.sol";
import {IAuction} from "../interfaces/IAuction.sol";
import {IBalancerVault} from "../interfaces/IBalancerVault.sol";

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
            Math.min(maxFuzzAmount[address(asset)], strategy.maxDeposit(user))
        );

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        skip(10 minutes);

        // Mock dYFI price feeds after skipping time but before reporting
        mockDYfiPriceFeeds();

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

    function test_operation_splitDeposit(
        IStrategyInterface strategy,
        uint256 _amount,
        uint256 _initialAmount,
        uint256 _dyfiRewardAmount
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        vm.assume(!strategy.useAuctions()); // SKIP this test if the strategy can only use auctions
        ERC20 asset = ERC20(strategy.asset());
        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)] * 2,
            Math.min(maxFuzzAmount[address(asset)], strategy.maxDeposit(user))
        );
        _initialAmount = bound(
            _initialAmount,
            minFuzzAmount[address(asset)],
            _amount - minFuzzAmount[address(asset)]
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
        uint256 _amountDeposited = mintAndDepositIntoStrategy(
            strategy,
            user,
            _initialAmount
        );

        assertEq(strategy.totalAssets(), _initialAmount, "!totalAssets");

        skip(1 minutes);

        airdropDYFI(address(strategy), _dyfiRewardAmount);

        // Disable health check
        vm.prank(management);
        strategy.setDoHealthCheck(false);

        // Mock dYFI price feeds after skipping time but before reporting
        mockDYfiPriceFeeds();

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");
        assertGt(asset.balanceOf(address(strategy)), 0);

        skip(strategy.profitMaxUnlockTime());

        if (strategy.maxDeposit(user) != 0) {
            _amountDeposited += mintAndDepositIntoStrategy(
                strategy,
                user,
                Math.min(_amount - _initialAmount, strategy.maxDeposit(user))
            );
        }

        // Withdraw all funds
        vm.startPrank(user);
        strategy.redeem(strategy.balanceOf(user), user, user);
        vm.stopPrank();

        assertGe(asset.balanceOf(user), _amountDeposited, "!final balance");
    }

    function test_profitableReport_airdrop(
        IStrategyInterface strategy,
        uint256 _amount,
        uint256 _dyfiRewardAmount
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        vm.assume(!strategy.useAuctions()); // SKIP this test if the strategy can only use auctions
        ERC20 asset = ERC20(strategy.asset());
        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)],
            Math.min(maxFuzzAmount[address(asset)], strategy.maxDeposit(user))
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

        // Mock dYFI price feeds before reporting
        mockDYfiPriceFeeds();

        vm.prank(management);
        strategy.setDoHealthCheck(false);

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
        vm.assume(!strategy.useAuctions()); // SKIP this test if the strategy can only use auctions
        ERC20 asset = ERC20(strategy.asset());
        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)],
            Math.min(maxFuzzAmount[address(asset)], strategy.maxDeposit(user))
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

        // Mock dYFI price feeds before reporting
        mockDYfiPriceFeeds();

        vm.prank(management);
        strategy.setDoHealthCheck(false);

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
        vm.assume(!strategy.useAuctions()); // SKIP this test if the strategy can only use auctions
        ERC20 asset = ERC20(strategy.asset());
        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)],
            Math.min(maxFuzzAmount[address(asset)], strategy.maxDeposit(user))
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

        // Mock dYFI price feeds before reporting
        mockDYfiPriceFeeds();

        vm.prank(management);
        strategy.setDoHealthCheck(false);

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
            Math.min(maxFuzzAmount[address(asset)], strategy.maxDeposit(user))
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

        // Mock dYFI price feeds after skipping time but before reporting
        mockDYfiPriceFeeds();

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
            Math.min(maxFuzzAmount[address(asset)], strategy.maxDeposit(user))
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

        // Mock dYFI price feeds after skipping time but before reporting
        mockDYfiPriceFeeds();

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
            Math.min(maxFuzzAmount[address(asset)], strategy.maxDeposit(user))
        );

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        skip(1 weeks);

        vm.mockCall(
            address(dYFIHelper.DYFI_REDEEMER),
            dYFIHelper.DYFI_REDEEMER.eth_required.selector,
            abi.encode(type(uint128).max) // very large number, but won't easily overflow
        );

        // Mock dYFI price feeds after skipping time but before reporting
        mockDYfiPriceFeeds();

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
            Math.min(maxFuzzAmount[address(asset)], strategy.maxDeposit(user))
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

        // Mock dYFI price feeds after skipping time but before reporting
        mockDYfiPriceFeeds();

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

    function test_dyfiBelowThreshold(
        IStrategyInterface strategy,
        uint256 _amount
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        ERC20 asset = ERC20(strategy.asset());
        address dYFI = tokenAddrs["dYFI"];
        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)],
            Math.min(maxFuzzAmount[address(asset)], strategy.maxDeposit(user))
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

        // Mock dYFI price feeds before reporting
        mockDYfiPriceFeeds();

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

        // Mock dYFI price feeds before reporting again
        mockDYfiPriceFeeds();

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

    function test_vaultsMaxWithdraw(
        IStrategyInterface strategy,
        uint256 _amount
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        ERC20 asset = ERC20(strategy.asset());

        // Bound amount to reasonable values
        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)],
            Math.min(maxFuzzAmount[address(asset)], strategy.maxDeposit(user))
        );

        // Disable health check for consistent behavior
        vm.prank(management);
        strategy.setDoHealthCheck(false);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        // Get initial withdrawable amount (before staking)
        uint256 initialWithdrawable = strategy.vaultsMaxWithdraw();
        assertApproxEqRel(
            initialWithdrawable,
            _amount,
            0.01e18,
            "Initial withdrawable amount incorrect"
        );

        // Stake the assets to ensure they're in the gauge
        vm.prank(keeper);
        strategy.tend();

        // Access internal vaultsMaxWithdraw implementation
        uint256 maxWithdraw = strategy.vaultsMaxWithdraw();

        // The maximum withdrawable should be the full amount (since we just staked it)
        assertApproxEqRel(
            maxWithdraw,
            _amount,
            0.01e18, // 1% tolerance for any rounding/fees
            "Max withdraw incorrect after staking"
        );

        // Test after partial withdrawal
        uint256 withdrawAmount = _amount / 2;
        vm.startPrank(user);
        strategy.withdraw(withdrawAmount, user, user);
        vm.stopPrank();

        // Verify max withdrawable decreased appropriately
        assertApproxEqRel(
            strategy.vaultsMaxWithdraw(),
            _amount - withdrawAmount,
            0.01e18,
            "Max withdraw incorrect after partial withdrawal"
        );
    }

    function test_balanceOfStake(
        IStrategyInterface strategy,
        uint256 _amount
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        ERC20 asset = ERC20(strategy.asset());

        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)],
            Math.min(maxFuzzAmount[address(asset)], strategy.maxDeposit(user))
        );

        assertEq(strategy.balanceOfStake(), 0);

        // Disable health check
        vm.prank(management);
        strategy.setDoHealthCheck(false);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        // Get amount in shares from the vault
        address vaultAddress = strategy.vault();
        IStrategy vault = IStrategy(vaultAddress);
        uint256 expectedShares = vault.convertToShares(_amount);

        // Now balanceOfStake should match the expected shares
        assertApproxEqRel(
            strategy.balanceOfStake(),
            expectedShares,
            0.001e18, // 1% tolerance for any potential rounding
            "Stake balance incorrect after staking"
        );

        // Test after partial withdrawal
        uint256 withdrawAmount = _amount / 2;
        uint256 withdrawShares = vault.convertToShares(withdrawAmount);

        vm.startPrank(user);
        strategy.withdraw(withdrawAmount, user, user);
        vm.stopPrank();

        // Verify balanceOfStake decreased appropriately
        assertApproxEqRel(
            strategy.balanceOfStake(),
            expectedShares - withdrawShares,
            0.01e18,
            "Stake balance incorrect after partial withdrawal"
        );
    }

    function test_receiveFlashLoan_revertNonBalancer(
        IStrategyInterface strategy
    ) public {
        vm.assume(_isFixtureStrategy(strategy));

        // Mock some data for the flashloan call
        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        uint256[] memory feeAmounts = new uint256[](1);
        feeAmounts[0] = 0;
        bytes memory userData = "";

        // Try to call from an address that isn't the Balancer Vault
        vm.prank(address(this));
        vm.expectRevert(bytes("!balancer"));
        strategy.receiveFlashLoan(tokens, amounts, feeAmounts, userData);
    }

    function test_receiveFlashLoan_revertWithFees(
        IStrategyInterface strategy
    ) public {
        vm.assume(_isFixtureStrategy(strategy));

        // Find the Balancer Vault address
        address balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8; // Balancer Vault address

        // Set up mock data with non-zero fees
        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        uint256[] memory feeAmounts = new uint256[](1);
        feeAmounts[0] = 100; // Non-zero fee
        bytes memory userData = "";

        vm.prank(address(strategy));
        strategy.setFlashLoanEnabled();

        // Mock call from Balancer Vault address
        vm.startPrank(balancerVault);
        vm.expectRevert(bytes("fee"));
        strategy.receiveFlashLoan(tokens, amounts, feeAmounts, userData);
        vm.stopPrank();
    }

    function test_receiveFlashLoan_revertNoDidNotInvoke(
        IStrategyInterface strategy,
        address caller
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        vm.assume(caller != address(strategy));
        airdropDYFI(address(strategy), maxDYFI());

        // Find the Balancer Vault address
        IBalancerVault balancerVault = IBalancerVault(
            0xBA12222222228d8Ba445958a75a0704d566BF2C8
        ); // Balancer Vault address

        // Set up mock data with non-zero fees
        address[] memory tokens = new address[](1);
        tokens[0] = address(strategy.WETH());
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e18;
        bytes memory userData = "";

        vm.startPrank(caller);
        vm.expectRevert(bytes("!enabled"));
        balancerVault.flashLoan(address(strategy), tokens, amounts, "");
        vm.stopPrank();
    }

    function test_setFlashLoanEnabled_validation(
        IStrategyInterface strategy,
        address caller
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        vm.assume(caller != address(strategy));

        vm.startPrank(caller);
        vm.expectRevert(bytes("!me"));
        strategy.setFlashLoanEnabled();
        vm.stopPrank();
    }

    function test_setAuction_validation(IStrategyInterface strategy) public {
        vm.assume(_isFixtureStrategy(strategy));

        // First, deploy a mock auction with incorrect parameters
        address mockInvalidAuction = address(
            new MockAuction(
                address(0xdead), // Different asset than strategy's
                address(0xbeef) // Different receiver than strategy
            )
        );

        // Should revert when want doesn't match strategy's asset
        vm.startPrank(management);
        vm.expectRevert(bytes("!want"));
        strategy.setAuction(mockInvalidAuction);
        vm.stopPrank();

        // Now deploy a mock auction with correct asset but wrong receiver
        address mockPartiallyValidAuction = address(
            new MockAuction(
                strategy.asset(), // Correct asset
                address(0xbeef) // Wrong receiver
            )
        );

        // Should revert when receiver doesn't match strategy
        vm.startPrank(management);
        vm.expectRevert(bytes("!receiver"));
        strategy.setAuction(mockPartiallyValidAuction);
        vm.stopPrank();

        // Finally, deploy a valid auction
        address mockValidAuction = address(
            new MockAuction(
                strategy.asset(), // Correct asset
                address(strategy) // Correct receiver
            )
        );

        // Should succeed with valid parameters
        vm.startPrank(management);
        strategy.setAuction(mockValidAuction);
        assertEq(
            strategy.auction(),
            mockValidAuction,
            "Auction not set correctly"
        );
        vm.stopPrank();

        // Verify setting to zero address also works (disables auction)
        vm.startPrank(management);
        strategy.setAuction(address(0));
        assertEq(
            strategy.auction(),
            address(0),
            "Auction not cleared correctly"
        );
        vm.stopPrank();
    }
}

// Mock auction contract for testing
contract MockAuction {
    address public want;
    address public receiver;

    constructor(address _want, address _receiver) {
        want = _want;
        receiver = _receiver;
    }

    function kick(address) external pure returns (uint256) {
        return 100; // Just return a dummy value
    }
}
