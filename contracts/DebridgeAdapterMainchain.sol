// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPool } from "./interfaces/IPool.sol";
import { IExternalCallExecutor } from "./interfaces/IExternalCallExecutor.sol";
import { IDlnSource } from "./interfaces/IDlnSource.sol";
import { DlnOrderLib } from "./libraries/DlnOrderLib.sol";
import { Helpers } from "./libraries/Helpers.sol";
import { DebridgeAdapterBase } from "./DebridgeAdapterBase.sol";

contract DebridgeAdapterMainchain is IExternalCallExecutor, DebridgeAdapterBase {
    using SafeERC20 for IERC20;

    event Borrow(
        bytes32 indexed orderId,
        address indexed borrower,
        address indexed asset,
        uint256 amount,
        address takeAsset,
        uint256 takeChainId,
        address receiver
    );

    event Withdraw(
        bytes32 indexed orderId,
        address indexed withdrawer,
        address indexed asset,
        uint256 amount,
        address takeAsset,
        uint256 takeChainId,
        address receiver
    );

    event Supply(
        bytes32 indexed orderId,
        address indexed supplier,
        address indexed asset,
        uint256 amount
    );

    event Repay(
        bytes32 indexed orderId,
        address indexed repayer,
        address indexed asset,
        uint256 amount,
        uint256 interestRateMode
    );

    event SetDlnExternalCallAdapter(
        address dlnExternalCallAdapter
    );

    error NotExternalCallAdapter();

    address public constant POOL = 0xbC92aaC2DBBF42215248B5688eB3D3d2b32F2c8d;

    address public dlnExternalCallAdapter;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address dlnSource_,
        address dlnExternalCallAdapter_
    ) public initializer {
        __DebridgeAdapterBase_init(dlnSource_);

        dlnExternalCallAdapter = dlnExternalCallAdapter_;
    }

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address takeAsset,
        uint256 takeChainId,
        address receiver
    ) external payable returns (bytes32) {
        if (asset == address(0)) revert ZeroAddress();

        IPool(POOL).borrow(
            asset,
            amount,
            interestRateMode,
            0,
            msg.sender
        );

        uint256 takeAmount = _calculateTakeAmount(amount);

        // preparing an order
        DlnOrderLib.OrderCreation memory orderCreation = Helpers.prepareOrder(
            address(this),
            asset,
            amount,
            takeAsset,
            takeAmount,
            takeChainId,
            receiver,
            ""
        );
    
        IERC20(asset).approve(dlnSource, amount);
        // placing an order
        bytes32 orderId = IDlnSource(dlnSource).createOrder{value: msg.value}(
            orderCreation,
            "",
            0,
            ""
        );

        emit Borrow(orderId, msg.sender, asset, amount, takeAsset, takeChainId, receiver);
        return orderId;
    }

    function withdraw(
        address asset,
        address mAsset,
        uint256 amount,
        address takeAsset,
        uint256 takeChainId,
        address receiver
    ) external payable returns (bytes32) {
        if (asset == address(0)) revert ZeroAddress();

        IERC20(mAsset).safeTransferFrom(msg.sender, address(this), amount);
        IPool(POOL).withdraw(
            asset,
            amount,
            address(this)
        );

        uint256 takeAmount = _calculateTakeAmount(amount);

        // preparing an order
        DlnOrderLib.OrderCreation memory orderCreation = Helpers.prepareOrder(
            address(this),
            asset,
            amount,
            takeAsset,
            takeAmount,
            takeChainId,
            receiver,
            ""
        );

        IERC20(asset).approve(dlnSource, amount);
        // placing an order
        bytes32 orderId = IDlnSource(dlnSource).createOrder{value: msg.value}(
            orderCreation,
            "",
            0,
            ""
        );

        emit Withdraw(orderId, msg.sender, asset, amount, takeAsset, takeChainId, receiver);
        return orderId;
    }

    function onEtherReceived(
        bytes32 _orderId,
        address _fallbackAddress,
        bytes memory _payload
    ) external payable returns (bool callSucceeded, bytes memory callResult) {}

    function onERC20Received(
        bytes32 orderId,
        address token,
        uint256 transferredAmount,
        address,
        bytes memory payload
    ) external returns (bool callSucceeded, bytes memory callResult) {
        if (msg.sender != dlnExternalCallAdapter) revert NotExternalCallAdapter();

        (
            ActionType actionType,
            address user,
            uint256 interestRateMode
        ) = abi.decode(payload, (ActionType, address, uint256));

        IERC20(token).approve(POOL, transferredAmount);

        if (actionType == ActionType.Supply) { // 0: supply
            IPool(POOL).supply(
                token,
                transferredAmount,
                user,
                0
            );
            emit Supply(orderId, user, token, transferredAmount);

        } else if (actionType == ActionType.Repay) { // 1: repay
            IPool(POOL).repay(
                token,
                transferredAmount,
                interestRateMode,
                user
            );
            emit Repay(orderId, user, token, transferredAmount, interestRateMode);
        }

        return (true, "");
    }

    function setDlnExternalCallAdapter(
        address dlnExternalCallAdapter_
    ) external onlyOwner {
        if (dlnExternalCallAdapter_ == address(0)) revert ZeroAddress();
        dlnExternalCallAdapter = dlnExternalCallAdapter_;

        emit SetDlnExternalCallAdapter(dlnExternalCallAdapter_);
    }
}
