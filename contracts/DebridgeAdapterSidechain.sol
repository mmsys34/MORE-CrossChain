// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IDlnSource } from "./interfaces/IDlnSource.sol";
import { DlnOrderLib } from "../contracts/libraries/DlnOrderLib.sol";
import { Helpers } from "../contracts/libraries/Helpers.sol";
import { DebridgeAdapterBase } from "./DebridgeAdapterBase.sol";

contract DebridgeAdapterSidechain is DebridgeAdapterBase {
    using SafeERC20 for IERC20;

    struct HookDataV1 {
        address fallbackAddress;
        address target;
        uint160 reward;
        bool isNonAtomic;
        bool isSuccessRequired;
        bytes targetPayload;
    }

    event Supply(
        bytes32 indexed orderId,
        address indexed supplier,
        address indexed asset,
        uint256 amount,
        address takeAsset,
        uint256 takeAmount,
        bytes externalCall
    );

    event Repay(
        bytes32 indexed orderId,
        address indexed repayer,
        address indexed asset,
        uint256 amount,
        uint256 interestRateMode,
        address takeAsset,
        uint256 takeAmount,
        bytes externalCall
    );

    event SetDebridgeAdapterMainchain(address debridgeAdapterMainchain);
 
    event SetSwapRouter(address swapRouter);

    uint256 public constant FLOW_INTERNAL_ID = 100000009;

    address public debridgeAdapterMainchain;
    address public swapRouter;
    address public usdc;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address dlnSource_,
        address debridgeAdapterMainchain_,
        address swapRouter_,
        address usdc_
    ) public initializer {
        __DebridgeAdapterBase_init(dlnSource_);

        debridgeAdapterMainchain = debridgeAdapterMainchain_;
        swapRouter = swapRouter_;
        usdc = usdc_;
    }

    function setDebridgeAdapterMainchain(
        address debridgeAdapterMainchain_
    ) external onlyOwner {
        if (debridgeAdapterMainchain_ == address(0)) revert ZeroAddress();
        debridgeAdapterMainchain = debridgeAdapterMainchain_;

        emit SetDebridgeAdapterMainchain(debridgeAdapterMainchain_);
    }

    function setSwapRouter(
        address swapRouter_
    ) external onlyOwner {
        if (swapRouter_ == address(0)) revert ZeroAddress();
        swapRouter = swapRouter_;

        emit SetSwapRouter(swapRouter_);
    }

    /**
     * @notice Supplies an `amount` of underlying asset into the reserve pool from a different chain.
     * @dev Always send `msg.value` for the bridge. It must be the same as the estimated fee.
     * @param asset The address of the underlying asset to be bridged from the source chain.
     * if asset is address(0), it means native token.
     * @param amount The amount to be supplied.
     */
    function supply(
        address asset,
        uint256 amount,
        address takeAsset,
        uint256 takeAmount
    ) external payable returns (bytes32) {
        if (asset == address(0)) revert ZeroAddress();

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    
        uint256 giveAmount = _swapToUSDC(asset, amount);
        bytes memory externalCall = _encodeHookDataV1(ActionType.Supply, msg.sender, 0);

        // preparing an order
        DlnOrderLib.OrderCreation memory orderCreation = Helpers.prepareOrder(
            msg.sender,
            usdc,
            giveAmount,
            takeAsset,
            takeAmount,
            FLOW_INTERNAL_ID,
            debridgeAdapterMainchain,
            externalCall
        );

        IERC20(usdc).approve(dlnSource, giveAmount);
        // placing an order
        bytes32 orderId = IDlnSource(dlnSource).createOrder{value: msg.value}(
            orderCreation,
            "",
            0,
            ""
        );

        emit Supply(orderId, msg.sender, asset, amount, takeAsset, takeAmount, externalCall);
        return orderId;
    }

    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address takeAsset,
        uint256 takeAmount
    ) external payable returns (bytes32) {
        if (asset == address(0)) revert ZeroAddress();

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
      
        uint256 giveAmount = _swapToUSDC(asset, amount);
        bytes memory externalCall = _encodeHookDataV1(ActionType.Repay, msg.sender, interestRateMode);

        // preparing an order
        DlnOrderLib.OrderCreation memory orderCreation = Helpers.prepareOrder(
            msg.sender,
            usdc,
            giveAmount,
            takeAsset,
            takeAmount,
            FLOW_INTERNAL_ID,
            debridgeAdapterMainchain,
            externalCall
        );

        IERC20(usdc).approve(dlnSource, giveAmount);
        // placing an order
        bytes32 orderId = IDlnSource(dlnSource).createOrder{value: msg.value}(
            orderCreation,
            "",
            0,
            ""
        );

        emit Repay(orderId, msg.sender, asset, amount, interestRateMode, takeAsset, takeAmount, externalCall);
        return orderId;
    }

    function _swapToUSDC(
        address tokenIn,
        uint256 amountIn
    ) internal returns (uint256) {
        if (tokenIn != usdc) {
            address[] memory path = new address[](2);
                path[0] = tokenIn;
                path[1] = usdc;

            return _swapSingleHopExactAmountIn(
                swapRouter,
                tokenIn,
                amountIn,
                path
            );
        } else return amountIn;
    }

    function _encodeHookDataV1(
        ActionType actionType,
        address onBehalfOf,
        uint256 interestRateMode
    ) internal view returns (bytes memory externalCallEnvelope) {
        // version prefix
        uint8 envelopeVersion = 1;

        bytes memory targetPayload = abi.encode(
            actionType,
            onBehalfOf,
            interestRateMode
        );
    
        HookDataV1 memory hookDataV1 = HookDataV1(
            onBehalfOf, // fallbackAddress
            debridgeAdapterMainchain, // target
            uint160(0), // reward
            false, // isNonAtomic
            true, // isSuccessRequired
            targetPayload // targetPayload
        );
    
        // encode the HookDataV1 fields
        bytes memory envelopeData = abi.encode(hookDataV1);

        // final externalCallEnvelope = envelopeVersion + envelopeData
        return abi.encode(envelopeVersion, envelopeData);
    }
}
