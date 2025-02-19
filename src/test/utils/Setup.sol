// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {ExtendedTest} from "./ExtendedTest.sol";

import {LLGaugeCompounderStrategiesFactory, OneUpGaugeCompounderStrategy} from "../../factories/LLGaugeCompounderStrategiesFactory.sol";
import {IBaseLLGaugeCompounderStrategy as IStrategyInterface} from "../../interfaces/IBaseLLGaugeCompounderStrategy.sol";

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";
import {IEvents} from "@tokenized-strategy/interfaces/IEvents.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IFactory {
    function governance() external view returns (address);

    function set_protocol_fee_bps(uint16) external;

    function set_protocol_fee_recipient(address) external;
}

contract Setup is ExtendedTest, IEvents {
    // Contract instances that we will use repeatedly.
    ERC20 public asset;
    IStrategy public vault;

    IStrategyInterface[] public fixtureStrategy;

    LLGaugeCompounderStrategiesFactory public strategyFactory;

    mapping(string => address) public tokenAddrs;

    // Addresses for different roles we will use repeatedly.
    address public user = address(10);
    address public keeper = address(4);
    address public management = address(1);
    address public performanceFeeRecipient = address(3);
    address public emergencyAdmin = address(5);

    // Address of the real deployed Factory
    address public factory;

    // Integer variables that will be used repeatedly.
    uint256 public decimals;
    uint256 public MAX_BPS = 10_000;

    uint256 public maxFuzzAmount = 1_000e18;
    uint256 public minFuzzAmount = 1e18;

    // Default profit max unlock time is set for 10 days
    uint256 public profitMaxUnlockTime = 10 days;

    function setUp() public virtual {
        _setTokenAddrs();

        // Set asset
        asset = ERC20(tokenAddrs["WETH"]);
        vault = IStrategyInterface(address(tokenAddrs["yvWETH-2"]));

        // Set decimals
        decimals = asset.decimals();

        strategyFactory = new LLGaugeCompounderStrategiesFactory(
            management,
            performanceFeeRecipient,
            keeper,
            emergencyAdmin
        );

        // Deploy strategy and set variables
        setUpStrategies();

        factory = fixtureStrategy[0].FACTORY();

        // label all the used addresses for traces
        vm.label(keeper, "keeper");
        vm.label(factory, "factory");
        vm.label(address(asset), "asset");
        vm.label(address(vault), "vault");
        vm.label(management, "management");
        vm.label(performanceFeeRecipient, "performanceFeeRecipient");
    }

    function setUpStrategies() public returns (address, address, address) {
        LLGaugeCompounderStrategiesFactory.LLStrategyTriple
            memory _strategies = strategyFactory.newStrategiesGroup(
                address(vault),
                "Tokenized Strategy",
                0
            );

        fixtureStrategy.push(IStrategyInterface(_strategies.coveStrategy));
        vm.label(_strategies.coveStrategy, "cove strategy");
        fixtureStrategy.push(IStrategyInterface(_strategies.oneUpStrategy));
        vm.label(_strategies.oneUpStrategy, "1up strategy");

        vm.startPrank(management);
        for (uint256 i; i < fixtureStrategy.length; ++i) {
            IStrategy _strategy = fixtureStrategy[i];
            _strategy.acceptManagement();
            _strategy.setProfitMaxUnlockTime(1 hours);
        }
        vm.stopPrank();

        return (
            _strategies.coveStrategy,
            _strategies.oneUpStrategy,
            address(0)
        );
    }

    function depositIntoStrategy(
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public {
        vm.prank(_user);
        asset.approve(address(_strategy), _amount);

        vm.prank(_user);
        _strategy.deposit(_amount, _user);
    }

    function mintAndDepositIntoStrategy(
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public {
        airdrop(asset, _user, _amount);
        depositIntoStrategy(_strategy, _user, _amount);
    }

    // For checking the amounts in the strategy
    function checkStrategyTotals(
        IStrategyInterface _strategy,
        uint256 _totalAssets,
        uint256 _totalDebt,
        uint256 _totalIdle
    ) public {
        uint256 _assets = _strategy.totalAssets();
        uint256 _balance = ERC20(_strategy.asset()).balanceOf(
            address(_strategy)
        );
        uint256 _idle = _balance > _assets ? _assets : _balance;
        uint256 _debt = _assets - _idle;
        assertEq(_assets, _totalAssets, "!totalAssets");
        assertEq(_debt, _totalDebt, "!totalDebt");
        assertEq(_idle, _totalIdle, "!totalIdle");
        assertEq(_totalAssets, _totalDebt + _totalIdle, "!Added");
    }

    function airdrop(ERC20 _asset, address _to, uint256 _amount) public {
        uint256 balanceBefore = _asset.balanceOf(_to);
        deal(address(_asset), _to, balanceBefore + _amount);
    }

    function airdropDYFI(address _to, uint256 _amount) public {
        ERC20 dYFI = ERC20(tokenAddrs["dYFI"]);
        vm.prank(0x2391Fc8f5E417526338F5aa3968b1851C16D894E); // dYFI reward pool
        dYFI.transfer(_to, _amount);
    }

    function maxDYFI() public view returns (uint256) {
        return
            ERC20(tokenAddrs["dYFI"]).balanceOf(
                0x2391Fc8f5E417526338F5aa3968b1851C16D894E
            );
    }

    // function setFees(uint16 _protocolFee, uint16 _performanceFee) public {
    //     address gov = IFactory(factory).governance();

    //     // Need to make sure there is a protocol fee recipient to set the fee.
    //     vm.prank(gov);
    //     IFactory(factory).set_protocol_fee_recipient(gov);

    //     vm.prank(gov);
    //     IFactory(factory).set_protocol_fee_bps(_protocolFee);

    //     vm.prank(management);
    //     strategy.setPerformanceFee(_performanceFee);
    // }

    function _setTokenAddrs() internal {
        tokenAddrs["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokenAddrs["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokenAddrs["yvWETH-2"] = 0xAc37729B76db6438CE62042AE1270ee574CA7571;
        tokenAddrs["dYFI"] = 0x41252E8691e964f7DE35156B68493bAb6797a275;
    }

    function _isFixtureStrategy(
        IStrategyInterface _strategy
    ) internal returns (bool) {
        for (uint256 i; i < fixtureStrategy.length; ++i) {
            if (fixtureStrategy[i] == _strategy) return true;
        }
        return false;
    }
}
