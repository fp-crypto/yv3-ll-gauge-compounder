// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {dYFIHelper} from "./libraries/dYFIHelper.sol";
import {IWETH} from "./interfaces/IWETH.sol";

import {Base4626Compounder, ERC20, IStrategy} from "@periphery/Bases/4626Compounder/Base4626Compounder.sol";
import {UniswapV3Swapper} from "@periphery/swappers/UniswapV3Swapper.sol";
import {AuctionSwapper} from "@periphery/swappers/AuctionSwapper.sol";

/// @title Euler Compounder Strategy
/// @dev Inherits Base4626Compounder for vault functionality
abstract contract BaseLLGaugeCompounderStrategy is
    Base4626Compounder,
    AuctionSwapper,
    UniswapV3Swapper
{
    /// @notice The Wrapped Ether contract address
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    bool public dontDumpDYfi;
    bool public dontSwapWeth;
    bool public useAuctions;

    /// @param _vault Address of the underlying vault
    /// @param _name Name of the strategy token
    constructor(
        address _vault,
        string memory _name
    ) Base4626Compounder(IStrategy(_vault).asset(), _name, _vault) {}

    function _claimAndSellRewards() internal override {
        _claimDYfi();

        if (!dontDumpDYfi) {
            dYFIHelper.dumpToWeth();
        }

        if (!dontSwapWeth) {
            _swapFrom(
                address(WETH),
                address(asset),
                ERC20(WETH).balanceOf(address(this)),
                0
            );
        }
    }

    function _claimDYfi() internal virtual;

    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        require(msg.sender == dYFIHelper.BALANCER_VAULT(), "!balancer");
        require(feeAmounts.length == 1 && feeAmounts[0] == 0, "fee");
        dYFIHelper.flashloanLogic(userData);
    }

    // Required to receive ETH from WETH withdrawal and Curve swap
    receive() external payable {}
}
