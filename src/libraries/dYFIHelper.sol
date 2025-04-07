// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IBalancerVault} from "../interfaces/IBalancerVault.sol";
import {ICurvePool} from "../interfaces/ICurvePool.sol";
import {IDYFIRedeemer} from "../interfaces/IDYFIRedeemer.sol";
import {IBaseLLGaugeCompounderStrategy} from "../interfaces/IBaseLLGaugeCompounderStrategy.sol";
import {IWETH} from "../interfaces/IWETH.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title dYFI Helper Library
/// @notice Helper functions for handling dYFI redemptions and conversions
/// @dev Provides functionality for converting dYFI to WETH through various paths
/// @custom:security-contact security@yearn.fi
library dYFIHelper {
    using SafeERC20 for IERC20;

    /// @notice Address of the dYFI token contract
    address private constant DYFI = 0x41252E8691e964f7DE35156B68493bAb6797a275;
    /// @notice Address of the YFI token contract
    address private constant YFI = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
    /// @notice Address of the WETH token contract
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @notice Balancer Vault contract for flash loans
    IBalancerVault public constant BALANCER_VAULT =
        IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    /// @notice Curve pool for dYFI/ETH swaps
    ICurvePool public constant CURVE_DYFI_ETH =
        ICurvePool(0x8aC64Ba8E440cE5c2d08688f4020698b1826152E);
    /// @notice Curve pool for YFI/ETH swaps
    ICurvePool public constant CURVE_YFI_ETH =
        ICurvePool(0xC26b89A667578ec7b3f11b2F98d6Fd15C07C54ba);
    /// @notice dYFI Redeemer contract for converting dYFI to YFI
    IDYFIRedeemer public constant DYFI_REDEEMER =
        IDYFIRedeemer(0x7dC3A74F0684fc026f9163C6D5c3C99fda2cf60a);

    /// @notice Converts dYFI tokens to WETH using the most profitable path
    /// @dev Compares direct Curve swap vs redeeming for YFI and then swapping
    /// @return _wethAmount Amount of WETH received from the conversion
    function dumpToWeth() external returns (uint256 _wethAmount) {
        return dumpToWeth(IERC20(DYFI).balanceOf(address(this)));
    }

    /// @notice Converts dYFI tokens to WETH using the most profitable path
    /// @dev Compares direct Curve swap vs redeeming for YFI and then swapping
    /// @param _dyfiAmount Amount of dYFI to convert
    /// @return _wethAmount Amount of WETH received from the conversion
    function dumpToWeth(
        uint256 _dyfiAmount
    ) public returns (uint256 _wethAmount) {
        if (_dyfiAmount == 0) return 0;

        uint256 amountOutSwap = CURVE_DYFI_ETH.get_dy(0, 1, _dyfiAmount);

        uint256 ethRequired = DYFI_REDEEMER.eth_required(_dyfiAmount);
        uint256 amountOutYfiEth = CURVE_YFI_ETH.get_dy(1, 0, _dyfiAmount);
        uint256 amountOutRedeem;
        if (amountOutYfiEth > ethRequired) {
            amountOutRedeem = amountOutYfiEth - ethRequired;
        }

        if (amountOutRedeem > amountOutSwap) {
            // Setup flash loan parameters
            address[] memory tokens = new address[](1);
            tokens[0] = WETH;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = ethRequired;

            // Encode the dYFI amount for the callback
            bytes memory userData = abi.encode(_dyfiAmount, ethRequired);

            // Execute flashLoan
            IBaseLLGaugeCompounderStrategy(address(this)).setFlashLoanEnabled();
            BALANCER_VAULT.flashLoan(address(this), tokens, amounts, userData);

            _wethAmount = amountOutRedeem;
        } else {
            approveSpend(DYFI, address(CURVE_DYFI_ETH), _dyfiAmount);
            _wethAmount = CURVE_DYFI_ETH.exchange(
                0,
                1,
                _dyfiAmount,
                amountOutSwap
            );
        }
    }

    /// @notice Executes the flash loan logic for dYFI redemption
    /// @dev Called by the Strategy inside the flashloan callback
    /// @param userData Encoded data containing dYFI amount and required ETH amount
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
        DYFI_REDEEMER.redeem{value: ethRequired}(dyfiAmount, address(this));

        // Approve YFI for Curve swap
        approveSpend(YFI, address(CURVE_YFI_ETH), dyfiAmount);

        // Swap YFI for ETH through Curve
        CURVE_YFI_ETH.exchange(1, 0, dyfiAmount, ethRequired);

        // Repay flashloan
        IERC20(WETH).safeTransfer(address(BALANCER_VAULT), ethRequired);
    }

    /// @notice Force approves token spending with an extra 1 wei for gas optimization
    /// @dev Adding 1 wei to the approval amount is an EVM gas optimization:
    ///      1. Keeps storage slots in non-zero state, which costs less gas than
    ///         allocating a new storage slot that was previously zero
    ///      2. In EVM, modifying a non-zero storage slot costs less gas than
    ///         modifying a slot from zero to non-zero
    ///      3. This is particularly efficient for protocols with frequent approvals
    ///         as it reduces gas costs over multiple transactions
    /// @param _token The token to approve spending of
    /// @param _spender The address to approve spending for
    /// @param _amount The amount to approve (will add 1 wei as optimization)
    function approveSpend(
        address _token,
        address _spender,
        uint256 _amount
    ) internal {
        IERC20(_token).forceApprove(_spender, _amount + 1);
    }
}
