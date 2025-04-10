// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IDlnSource } from "./interfaces/IDlnSource.sol";
import { IUniswapV2Router02 } from "./interfaces/IUniswapV2Router02.sol";

abstract contract DebridgeAdapterBase is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    enum ActionType {
        Supply,
        Repay
    }

    error ZeroAddress();
    error TooMuchRequested(address routerV2);

    event RecoverToken(address indexed token, address indexed to, uint256 amount);
    event SetDlnSource(address dlnSource);

    address public dlnSource;

    function __DebridgeAdapterBase_init(
        address dlnSource_
    ) internal onlyInitializing {
        __Ownable_init(msg.sender);

        dlnSource = dlnSource_;
    }

    /**
     * @notice This function returns the global fixed fee in the native asset of the protocol.
     * @dev This fee is denominated in the native asset (like Ether in Ethereum).
     * @return uint88 This return value represents the global fixed fee in the native asset.
     */
    function getFixedNativeFee() external returns (uint88) {
        return IDlnSource(dlnSource).globalFixedNativeFee();
    }

    /**
     * @notice This function provides the global transfer fee, expressed in Basis Points (BPS).
     * @dev It retrieves a global fee which is applied to order.giveAmount. The fee is represented in Basis Points (BPS), where 1 BPS equals 0.01%.
     * @return uint16 The return value represents the global transfer fee in BPS.
     */
    function getTransferFeeBps() external returns (uint88) {
        return IDlnSource(dlnSource).globalTransferFeeBps();
    }

    /// @dev Recovers the token sent to this contract by mistake
    /// @dev only owner
    /// @param token The token to recover. if 0x0 then it is native token
    /// @param to The address to send the token to
    /// @param amount The amount to send
    function recoverToken(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(to, amount);

        emit RecoverToken(token, to, amount);
    }

    function setDlnSource(address dlnSource_) external onlyOwner {
        if (dlnSource_ == address(0)) revert ZeroAddress();
        dlnSource = dlnSource_;

        emit SetDlnSource(dlnSource_);
    }

    function _swapSingleHopExactAmountIn(
        address routerV2,
        address tokenIn,
        uint256 amountIn,
        address[] memory path
    ) internal returns (uint256 amountOut) {
        // approve fist
        IERC20(tokenIn).approve(routerV2, amountIn);

        uint256[] memory amountsOut = IUniswapV2Router02(routerV2).getAmountsOut(amountIn, path);

        uint256 amountOutMin = (amountsOut[amountsOut.length - 1] * 995) / 1000; // 0.5% slippage
        if (amountOutMin == 0) revert TooMuchRequested(routerV2);
        // do swap
        amountsOut = IUniswapV2Router02(routerV2).swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            block.timestamp
        );

        return amountsOut[amountsOut.length - 1];
    }
}
