// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {ExtendedTest} from "./ExtendedTest.sol";

import {CoveGaugeCompounderStrategyFactory} from "../../factories/CoveGaugeCompounderStrategyFactory.sol";
import {OneUpGaugeCompounderStrategyFactory} from "../../factories/OneUpGaugeCompounderStrategyFactory.sol";
import {StakeDaoGaugeCompounderStrategyFactory} from "../../factories/StakeDaoGaugeCompounderStrategyFactory.sol";
import {LLGaugeCompounderVaultFactory} from "../../factories/LLGaugeCompounderVaultFactory.sol";
import {IBaseLLGaugeCompounderStrategy as IStrategyInterface} from "../../interfaces/IBaseLLGaugeCompounderStrategy.sol";
import {IAuctionFactory} from "../../interfaces/IAuctionFactory.sol";

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";
import {IEvents} from "@tokenized-strategy/interfaces/IEvents.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Interface for Chainlink Aggregator
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

interface IFactory {
    function governance() external view returns (address);

    function set_protocol_fee_bps(uint16) external;

    function set_protocol_fee_recipient(address) external;
}

contract Setup is ExtendedTest, IEvents {
    IStrategyInterface[] public fixtureStrategy;

    // Chainlink feed addresses
    address public constant ETH_USD_FEED =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant YFI_USD_FEED =
        0xA027702dbb89fbd58938e4324ac03B58d812b0E1;

    LLGaugeCompounderVaultFactory public vaultFactory;

    mapping(string => address) public tokenAddrs;

    // Addresses for different roles we will use repeatedly.
    address public user = address(10);
    address public keeper = address(4);
    address public management = address(1);
    address public performanceFeeRecipient = address(3);
    address public emergencyAdmin = address(5);
    address public roleManager = address(7);

    // Address of the real deployed Factory
    address public factory;

    // Integer variables that will be used repeatedly.
    uint256 public MAX_BPS = 10_000;

    mapping(address => uint256) public minFuzzAmount;
    mapping(address => uint256) public maxFuzzAmount;

    // Default profit max unlock time is set for 10 days
    uint256 public profitMaxUnlockTime = 10 days;

    function setUp() public virtual {
        _setTokenAddrs();
        _setFuzzLimits();

        LLGaugeCompounderVaultFactory.LLTriple
            memory factories = LLGaugeCompounderVaultFactory.LLTriple({
                cove: address(
                    new CoveGaugeCompounderStrategyFactory(
                        management,
                        performanceFeeRecipient,
                        keeper,
                        emergencyAdmin
                    )
                ),
                oneUp: address(
                    new OneUpGaugeCompounderStrategyFactory(
                        management,
                        performanceFeeRecipient,
                        keeper,
                        emergencyAdmin
                    )
                ),
                stakeDao: address(
                    new StakeDaoGaugeCompounderStrategyFactory(
                        management,
                        performanceFeeRecipient,
                        keeper,
                        emergencyAdmin
                    )
                )
            });

        vaultFactory = new LLGaugeCompounderVaultFactory(
            roleManager,
            factories.cove,
            factories.oneUp,
            factories.stakeDao
        );

        // Deploy strategy and set variables
        setUpStrategies(IStrategy(tokenAddrs["yvWETH-2"]), 0);
        setUpStrategies(IStrategy(tokenAddrs["yvUSDC-1"]), 500);
        setUpStrategies(IStrategy(tokenAddrs["yvDAI-2"]), 500);
        setUpStrategies(IStrategy(tokenAddrs["yvcrvUSD-2"]), 0);

        factory = fixtureStrategy[0].FACTORY();

        // label all the used addresses for traces
        vm.label(keeper, "keeper");
        vm.label(factory, "factory");
        vm.label(management, "management");
        vm.label(performanceFeeRecipient, "performanceFeeRecipient");
    }

    function setUpStrategies(
        IStrategy vault,
        uint24 wethAssetSwapFee
    ) public returns (LLGaugeCompounderVaultFactory.LLTriple memory) {
        vaultFactory.newLLCompounderVault(
            address(vault),
            "yVaultLLCompounder",
            "yvXYZ-LL",
            wethAssetSwapFee
        );

        LLGaugeCompounderVaultFactory.LLTriple memory _strategies = vaultFactory
            .strategyDeploymentsByVault(address(vault));

        uint256 i = fixtureStrategy.length; // starting point is length before pushing

        fixtureStrategy.push(IStrategyInterface(_strategies.cove));
        vm.label(_strategies.cove, "CoveStrategy");
        fixtureStrategy.push(IStrategyInterface(_strategies.oneUp));
        vm.label(_strategies.oneUp, "OneUpStrategy");
        fixtureStrategy.push(IStrategyInterface(_strategies.stakeDao));
        vm.label(_strategies.stakeDao, "StakeDaoStrategy");

        vm.label(IStrategyInterface(_strategies.cove).vault(), "yVault");
        vm.label(IStrategyInterface(_strategies.cove).Y_GAUGE(), "yGauge");

        vm.startPrank(management);
        for (; i < fixtureStrategy.length; ++i) {
            IStrategyInterface _strategy = fixtureStrategy[i];
            _strategy.acceptManagement();
            _strategy.setProfitMaxUnlockTime(1 hours);
            _strategy.setOpenDeposits(true);
            _strategy.setMinDYfiToSell(0);
            _strategy.setUseAuctions(
                wethAssetSwapFee == 0 && _strategy.asset() != tokenAddrs["WETH"]
            );
        }
        vm.stopPrank();

        return _strategies;
    }

    function depositIntoStrategy(
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public returns (uint256) {
        ERC20 asset = ERC20(_strategy.asset());

        vm.prank(_user);
        asset.approve(address(_strategy), _amount);

        vm.prank(_user);
        return _strategy.deposit(_amount, _user);
    }

    function mintAndDepositIntoStrategy(
        IStrategyInterface _strategy,
        address _user,
        uint256 _amount
    ) public returns (uint256) {
        airdrop(ERC20(_strategy.asset()), _user, _amount);
        return depositIntoStrategy(_strategy, _user, _amount);
    }

    // For checking the amounts in the strategy
    function checkStrategyTotals(
        IStrategyInterface _strategy,
        uint256 _totalAssets,
        uint256 _totalDebt,
        uint256 _totalIdle
    ) public view {
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
        return 1e18;
            //ERC20(tokenAddrs["dYFI"]).balanceOf(
            //    0x2391Fc8f5E417526338F5aa3968b1851C16D894E
            //);
    }

    function _setTokenAddrs() internal {
        _setTokenAddr("WETH", 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        _setTokenAddr("USDC", 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        _setTokenAddr("DAI", 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        _setTokenAddr("crvUSD", 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
        _setTokenAddr("yvWETH-2", 0xAc37729B76db6438CE62042AE1270ee574CA7571);
        _setTokenAddr("yvUSDC-1", 0xBe53A109B494E5c9f97b9Cd39Fe969BE68BF6204);
        _setTokenAddr("yvDAI-2", 0x92545bCE636E6eE91D88D2D017182cD0bd2fC22e);
        _setTokenAddr("yvcrvUSD-2", 0xBF319dDC2Edc1Eb6FDf9910E39b37Be221C8805F);
        _setTokenAddr("dYFI", 0x41252E8691e964f7DE35156B68493bAb6797a275);
    }

    function _setTokenAddr(string memory symbol, address addr) internal {
        tokenAddrs[symbol] = addr;
        vm.label(addr, symbol);
    }

    function _setFuzzLimits() internal {
        maxFuzzAmount[tokenAddrs["WETH"]] = 1_000e18;
        minFuzzAmount[tokenAddrs["WETH"]] = 1e18;
        maxFuzzAmount[tokenAddrs["USDC"]] = 1_000_000e6;
        minFuzzAmount[tokenAddrs["USDC"]] = 1_000e6;
        maxFuzzAmount[tokenAddrs["DAI"]] = 1_000_000e18;
        minFuzzAmount[tokenAddrs["DAI"]] = 1_000e18;
        maxFuzzAmount[tokenAddrs["crvUSD"]] = 1_000_000e18;
        minFuzzAmount[tokenAddrs["crvUSD"]] = 1_000e18;
    }

    function _createAuction(
        IStrategyInterface _strategy
    ) internal returns (address) {
        return
            IAuctionFactory(0xa076c247AfA44f8F006CA7f21A4EF59f7e4dc605)
                .createNewAuction(
                    _strategy.asset(),
                    address(_strategy),
                    management
                );
    }

    function _isFixtureStrategy(
        IStrategyInterface _strategy
    ) internal view returns (bool) {
        for (uint256 i; i < fixtureStrategy.length; ++i) {
            if (fixtureStrategy[i] == _strategy) return true;
        }
        return false;
    }

    /**
     * @notice Mock Chainlink Oracle responses to prevent "price too old" errors during testing
     * @dev This function mocks the Chainlink oracle to return the latest price data
     *      with the current block.timestamp, which prevents price staleness errors
     *      that can occur during testing when time is manipulated with vm.skip()
     * @param oracle The Chainlink oracle address to mock
     */
    function mockChainlinkOracle(address oracle) internal {
        // Fetch the current round data
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt, // updatedAt - we'll replace this
            ,
            uint80 answeredInRound
        ) = AggregatorV3Interface(oracle).latestRoundData();

        // Mock the latestRoundData function to always return fresh data
        vm.mockCall(
            oracle,
            abi.encodeWithSelector(
                AggregatorV3Interface.latestRoundData.selector
            ),
            abi.encode(
                roundId,
                answer,
                startedAt,
                block.timestamp, // Keep the updatedAt timestamp current
                answeredInRound
            )
        );
    }

    /**
     * @notice Mock dYFI price feed oracles needed for the tests
     * @dev This function mocks the Chainlink oracles used in the dYFI strategy
     *      to prevent "price too old" errors during time-skipping tests
     */
    function mockDYfiPriceFeeds() internal {
        mockChainlinkOracle(ETH_USD_FEED);
        mockChainlinkOracle(YFI_USD_FEED);
    }
}
