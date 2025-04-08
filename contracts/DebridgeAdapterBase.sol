// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IDlnSource } from "./interfaces/IDlnSource.sol";

abstract contract DebridgeAdapterBase is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    enum ActionType {
        Supply,
        Repay
    }

    error ZeroAddress();

    event RecoverToken(address indexed token, address indexed to, uint256 amount);
    event SetDlnSource(address dlnSource);
    event SetVariableFee(uint256 variableFee);
    event SetSolverGasCost(uint256 solverGasCost);

    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public variableFee;
    uint256 public solverGasCost;

    address public dlnSource;

    function __DebridgeAdapterBase_init(
        address dlnSource_
    ) internal onlyInitializing {
        __Ownable_init(msg.sender);

        dlnSource = dlnSource_;
        variableFee = 4; // denominated in bps
        solverGasCost = 5e5; // $0.5 
    }

    function getFixedNativeFee() external returns (uint88) {
        return IDlnSource(dlnSource).globalFixedNativeFee();
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

    function setVariableFee(uint256 variableFee_) external onlyOwner {
        variableFee = variableFee_;

        emit SetVariableFee(variableFee_);
    }

    function setSolverGasCost(uint256 solverGasCost_) external onlyOwner {
        solverGasCost = solverGasCost_;

        emit SetSolverGasCost(solverGasCost_);
    }

    function setDlnSource(address dlnSource_) external onlyOwner {
        if (dlnSource_ == address(0)) revert ZeroAddress();
        dlnSource = dlnSource_;

        emit SetDlnSource(dlnSource_);
    }

    function _calculateTakeAmount(
        uint256 giveAmount
    ) internal returns (uint256) {
        uint256 transferFee = IDlnSource(dlnSource).globalTransferFeeBps();
        return giveAmount * (BPS_DENOMINATOR - transferFee - variableFee) / BPS_DENOMINATOR - solverGasCost;
    }
}
