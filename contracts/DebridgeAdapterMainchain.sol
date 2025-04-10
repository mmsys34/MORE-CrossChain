// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPool } from "./interfaces/IPool.sol";
import { IExternalCallExecutor } from "./interfaces/IExternalCallExecutor.sol";
import { IDlnSource } from "./interfaces/IDlnSource.sol";
import { IKittyRouterNgPoolsOnly } from "./interfaces/IKittyRouterNgPoolsOnly.sol";
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
        uint256 takeAmount,
        uint256 takeChainId
    );

    event Withdraw(
        bytes32 indexed orderId,
        address indexed withdrawer,
        address indexed asset,
        uint256 amount,
        address takeAsset,
        uint256 takeAmount,
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
    address public constant USDF = 0x2aaBea2058b5aC2D339b163C6Ab6f2b6d53aabED;
    address public constant USDC = 0xF1815bd50389c46847f0Bda824eC8da914045D14;
    address public constant STABLEGATE = 0x20ca5d1C8623ba6AC8f02E41cCAFFe7bb6C92B57;

    address public punchSwapRouter;
    address public kittySwapRouter;
    address public dlnExternalCallAdapter;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address dlnSource_,
        address dlnExternalCallAdapter_,
        address punchSwapRouter_,
        address kittySwapRouter_
    ) public initializer {
        __DebridgeAdapterBase_init(dlnSource_);

        dlnExternalCallAdapter = dlnExternalCallAdapter_;
        punchSwapRouter = punchSwapRouter_;
        kittySwapRouter = kittySwapRouter_;
    }

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address takeAsset,
        uint256 takeAmount,
        uint256 takeChainId
    ) external payable returns (bytes32) {
        if (asset == address(0)) revert ZeroAddress();
        // 1. borrow a specific asset from MORE Markets
        IPool(POOL).borrow(
            asset,
            amount,
            interestRateMode,
            0,
            msg.sender
        );
        // 2. if asset is not USDC(f.g. WETH), swap it to USDC
        uint256 giveAmount = _swapToUSDC(asset, amount);

        // preparing an order
        DlnOrderLib.OrderCreation memory orderCreation = Helpers.prepareOrder(
            msg.sender,
            USDC,
            giveAmount,
            takeAsset,
            takeAmount,
            takeChainId,
            msg.sender,
            ""
        );
    
        IERC20(USDC).approve(dlnSource, amount);
        // placing an order
        bytes32 orderId = IDlnSource(dlnSource).createOrder{value: msg.value}(
            orderCreation,
            "",
            0,
            ""
        );

        emit Borrow(orderId, msg.sender, asset, amount, takeAsset, takeAmount, takeChainId);
        return orderId;
    }

    function withdraw(
        address asset,
        address mAsset,
        uint256 amount,
        address takeAsset,
        uint256 takeAmount,
        uint256 takeChainId,
        address receiver
    ) external payable returns (bytes32) {
        if (asset == address(0)) revert ZeroAddress();

        IERC20(mAsset).safeTransferFrom(msg.sender, address(this), amount);
        IPool(POOL).withdraw(asset, amount, address(this));

        uint256 giveAmount = _swapToUSDC(asset, amount);

        // preparing an order
        DlnOrderLib.OrderCreation memory orderCreation = Helpers.prepareOrder(
            msg.sender,
            USDC,
            giveAmount,
            takeAsset,
            takeAmount,
            takeChainId,
            receiver,
            ""
        );

        IERC20(USDC).approve(dlnSource, amount);
        // placing an order
        bytes32 orderId = IDlnSource(dlnSource).createOrder{value: msg.value}(
            orderCreation,
            "",
            0,
            ""
        );

        emit Withdraw(orderId, msg.sender, asset, amount, takeAsset, takeAmount, takeChainId, receiver);
        return orderId;
    }

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

    function onEtherReceived(
        bytes32 _orderId,
        address _fallbackAddress,
        bytes memory _payload
    ) external payable returns (bool callSucceeded, bytes memory callResult) {}

    function setDlnExternalCallAdapter(
        address dlnExternalCallAdapter_
    ) external onlyOwner {
        if (dlnExternalCallAdapter_ == address(0)) revert ZeroAddress();
        dlnExternalCallAdapter = dlnExternalCallAdapter_;

        emit SetDlnExternalCallAdapter(dlnExternalCallAdapter_);
    }

    function _swapToUSDC(
        address tokenIn,
        uint256 amountIn
    ) internal returns (uint256) {
        if (tokenIn != USDC) {
            address[] memory path = new address[](2);
                path[0] = tokenIn;
                path[1] = USDF;

            uint256 amountOut1 = _swapSingleHopExactAmountIn(
                punchSwapRouter,
                tokenIn,
                amountIn,
                path
            );
            return _stableSwap(amountOut1);

        } else return amountIn;
    }

    function _stableSwap(uint256 amountIn) internal returns (uint256) {
        // approve fist
        IERC20(USDF).approve(kittySwapRouter, amountIn);
        address[11] memory routes = [
            USDF,
            STABLEGATE,
            USDC,
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        ];

        uint256[4][5] memory swapParams = [
            [uint256(0), uint256(1), uint256(1), uint256(10)],
            [uint256(0), uint256(0), uint256(0), uint256(0)],
            [uint256(0), uint256(0), uint256(0), uint256(0)],
            [uint256(0), uint256(0), uint256(0), uint256(0)],
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        ];

        uint256 amountOutMin = (amountIn * 98) / 100; // 2% slippage

        return IKittyRouterNgPoolsOnly(kittySwapRouter).exchange(
            routes,
            swapParams,
            amountIn,
            amountOutMin,
            address(this)
        );
    }
}
