// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IdYFIRedeemer} from "../interfaces/IdYFIRedeemer.sol";
import {IBalancerVault} from "../interfaces/IBalancerVault.sol";
import {ICurvePool} from "../interfaces/ICurvePool.sol";
import {IdYFIRedeemer} from "../interfaces/IdYFIRedeemer.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library dYFIHelper {
    using SafeERC20 for IERC20;

    address private constant DYFI = 0x41252E8691e964f7DE35156B68493bAb6797a275;
    address private constant YFI = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IBalancerVault public constant BALANCER_VAULT =
        IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    ICurvePool public constant CURVE_DYFI_ETH =
        ICurvePool(0x8aC64Ba8E440cE5c2d08688f4020698b1826152E);
    ICurvePool public constant CURVE_YFI_ETH =
        ICurvePool(0xC26b89A667578ec7b3f11b2F98d6Fd15C07C54ba);
    IDYFIRedeemer public constant DYFI_REDEEMER =
        IdYFIRedeemer(0x7dC3A74F0684fc026f9163C6D5c3C99fda2cf60a);

    function dumpToWeth(
        uint256 _dyfiAmount
    ) external returns (uint256 _wethAmount) {
        uint256 amountOutCurve = CURVE_DYFI_ETH.get_dy(0, 1, _dyfiAmount);

        uint256 ethRequired = DYFI_REDEEMER.eth_required(_dyfiAmount);
        uint256 amountOutRedeem = CURVE_YFI_ETH.get_dy(0, 1, _dyfiAmount) -
            ethRequired;

        bool redeem = amountOutRedeem > amountOutCurve;

        if (redeem) {
            // Setup flash loan parameters
            address[] memory tokens = new address[](1);
            tokens[0] = WETH;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = ethRequired;

            // Encode the dYFI amount for the callback
            bytes memory userData = abi.encode(_dyfiAmount, ethRequired);

            // Execute flash loan
            BALANCER_VAULT.flashLoan(
                address(this),
                tokens,
                amounts,
                userData
            );

            _wethAmount = amountOutRedeem;
        } else {
            amountOutCurve.exchange(0, 1, _dyfiAmount, amountOutCurve);
        }
    }

    function flashloanLogic(bytes memory userData) external {
        // Decode the dYFI amount from userData
        (uint256 dyfiAmount, uint256 ethRequired) = abi.decode(
            userData,
            (uint256, uint256)
        );

        // Unwrap WETH to ETH
        IWETH(WETH).withdraw(ethRequired);

        // Approve dYFI for redemption
        approveSpend(DYFI, address(DYFI_REDEEMER), dyfiAmount);

        // Redeem dYFI for YFI
        DYFI_REDEEMER.redeem{value: ethRequired}(dyfiAmount);

        // Approve YFI for Curve swap
        approveSpend(YFI, address(CURVE_YFI_ETH), dyfiAmount);

        // Swap YFI for ETH through Curve
        CURVE_YFI_ETH.exchange(0, 1, dyfiAmount, minOut);

        // Approve WETH for flash loan repayment
        approveSpend(WETH, BALANCER_VAULT, ethRequired);
    }

    function approveSpend(
        address _token,
        address _spender,
        uint256 _amount
    ) internal {
        IERC20(_token).safeApprove(_spender, _amount + 1);
    }
}
