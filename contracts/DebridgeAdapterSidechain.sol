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

    error InsufficientAmount();

    uint256 public constant FLOW_INTERNAL_ID = 100000009;
    address public constant FLOW_USDC = 0xF1815bd50389c46847f0Bda824eC8da914045D14;

    address public debridgeAdapterMainchain;

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

    event SetDebridgeAdapterMainchain(
        address debridgeAdapterMainchain
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address dlnSource_,
        address debridgeAdapterMainchain_
    ) public initializer {
        __DebridgeAdapterBase_init(dlnSource_);

        debridgeAdapterMainchain = debridgeAdapterMainchain_;
    }

    function setDebridgeAdapterMainchain(
        address debridgeAdapterMainchain_
    ) external onlyOwner {
        if (debridgeAdapterMainchain_ == address(0)) revert ZeroAddress();
        debridgeAdapterMainchain = debridgeAdapterMainchain_;

        emit SetDebridgeAdapterMainchain(debridgeAdapterMainchain_);
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
        uint256 amount
    ) external payable returns (bytes32) {
        // getting the protocol fee
        uint256 protocolFee = IDlnSource(dlnSource).globalFixedNativeFee();

        uint256 takeAmount = _calculateTakeAmount(amount);

        if (asset != address(0)) {
            IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
            IERC20(asset).approve(dlnSource, amount);
        } else { // native in ETH
            if (msg.value < amount + protocolFee) revert InsufficientAmount();
        }
    
        bytes memory externalCall = _encodeHookDataV1(ActionType.Supply, msg.sender, 0);

        // preparing an order
        DlnOrderLib.OrderCreation memory orderCreation = Helpers.prepareOrder(
            address(this),
            asset,
            amount,
            FLOW_USDC,
            takeAmount,
            FLOW_INTERNAL_ID,
            debridgeAdapterMainchain,
            externalCall
        );

        // placing an order
        bytes32 orderId = IDlnSource(dlnSource).createOrder{value: protocolFee}(
            orderCreation,
            "",
            0,
            ""
        );

        emit Supply(orderId, msg.sender, asset, amount);
        return orderId;
    }

    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external payable returns (bytes32) {
        // getting the protocol fee
        uint256 protocolFee = IDlnSource(dlnSource).globalFixedNativeFee();
        uint256 takeAmount = _calculateTakeAmount(amount);

        if (asset != address(0)) {
            IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
            IERC20(asset).approve(dlnSource, amount);
        } else { // native in ETH
            if (msg.value < amount + protocolFee) revert InsufficientAmount();
        }

        bytes memory externalCall = _encodeHookDataV1(ActionType.Repay, msg.sender, interestRateMode);

        // preparing an order
        DlnOrderLib.OrderCreation memory orderCreation = Helpers.prepareOrder(
            address(this),
            asset,
            amount,
            FLOW_USDC,
            takeAmount,
            FLOW_INTERNAL_ID,
            debridgeAdapterMainchain,
            externalCall
        );

        // placing an order
        bytes32 orderId = IDlnSource(dlnSource).createOrder{value: protocolFee}(
            orderCreation,
            "",
            0,
            ""
        );

        emit Repay(orderId, msg.sender, asset, amount, interestRateMode);
        return orderId;
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
    
        // encode the HookDataV1 fields
        bytes memory envelopeData = abi.encode(
            address(0), // fallbackAddress
            debridgeAdapterMainchain, // target
            0, // reward
            false, // isNonAtomic
            true, // isSuccessRequired
            targetPayload // targetPayload
        );

        // final externalCallEnvelope = envelopeVersion + envelopeData
        return abi.encode(envelopeVersion, envelopeData);
    }
}
