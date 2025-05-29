pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {LLGaugeCompounderStrategyAprOracle as StrategyAprOracle} from "../periphery/StrategyAprOracle.sol";

contract OracleTest is Setup {
    StrategyAprOracle public oracle;

    function setUp() public override {
        super.setUp();
        oracle = new StrategyAprOracle(management);
        vm.prank(management);
        oracle.setIsStable(tokenAddrs["crvUSD"], true);
    }

    function checkOracle(address _strategy, uint256 _delta) public {
        uint256 currentApr = oracle.aprAfterDebtChange(_strategy, 0);
        console.log("strategy: %s", IStrategyInterface(_strategy).name());
        console.log("currentApr: %e", currentApr);
        console.log("baseApr: %e", oracle.baseApr(_strategy, 0));
        console.log("dyfiApr: %e", oracle.dyfiApr(_strategy, 0));

        // Debug additional information
        address strategyAsset = address(IStrategyInterface(_strategy).asset());
        uint256 totalAssets = IStrategyInterface(_strategy).totalAssets();
        console.log("totalAssets: %e", totalAssets);
        console.log("Asset address: %s", strategyAsset);
        console.log(
            "Is stable: %s",
            oracle.isStable(strategyAsset) ? "true" : "false"
        );

        // Should be greater than 0 but likely less than 100%
        assertGt(currentApr, 0, "ZERO");
        assertLt(currentApr, 1e18, "+100%");

        uint256 negativeDebtChangeApr = oracle.aprAfterDebtChange(
            _strategy,
            -int256(_delta)
        );
        console.log("negativeDebtChangeApr: %e", negativeDebtChangeApr);

        // The apr should go up if deposits go down
        assertLt(currentApr, negativeDebtChangeApr, "negative change");

        uint256 positiveDebtChangeApr = oracle.aprAfterDebtChange(
            _strategy,
            int256(_delta)
        );
        console.log("positiveDebtChangeApr: %e", positiveDebtChangeApr);

        // The apr should go down if deposits go up
        assertGt(currentApr, positiveDebtChangeApr, "positive change");
    }

    function test_oracle(
        IStrategyInterface strategy,
        uint256 _amount,
        uint16 _percentChange
    ) public {
        vm.assume(_isFixtureStrategy(strategy));
        ERC20 asset = ERC20(strategy.asset());
        _amount = bound(
            _amount,
            minFuzzAmount[address(asset)],
            Math.min(maxFuzzAmount[address(asset)], strategy.maxDeposit(user))
        );
        _percentChange = uint16(
            bound(uint256(_percentChange), 10, MAX_BPS - 1)
        );
        uint256 _delta = (_amount * _percentChange) / MAX_BPS;

        mintAndDepositIntoStrategy(strategy, user, _amount);

        checkOracle(address(strategy), _delta);
    }
}
