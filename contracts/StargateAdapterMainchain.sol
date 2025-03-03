// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ILayerZeroComposer } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import { IPool } from "./interfaces/IPool.sol";
import "./StargateAdapterBase.sol";

contract StargateAdapterMainchain is ILayerZeroComposer, StargateAdapterBase {
    using SafeERC20 for IERC20;

    event Borrow(
        address indexed borrower,
        address indexed asset,
        address indexed stargateOFT,
        uint256 amount,
        uint32 dstEndpointId,
        address receiver
    );

    event Withdraw(
        address indexed withdrawer,
        address indexed asset,
        address indexed stargateOFT,
        uint256 amount,
        uint32 dstEndpointId,
        address receiver
    );

    event Supply(
        address indexed supplier,
        address indexed asset,
        address indexed stargateOFT,
        uint256 amount
    );

    event Repay(
        address indexed repayer,
        address indexed asset,
        address indexed stargateOFT,
        uint256 amount,
        uint256 interestRateMode
    );

    error NotCrossChain();
    error NotLzEndpoint();
    error NotStargateOFT();

    address public constant POOL = 0xbC92aaC2DBBF42215248B5688eB3D3d2b32F2c8d;
    address public lzEndpoint;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address lzEndpoint_) public initializer {
        __Ownable_init(msg.sender);
        __StargateAdapterBase_init();

        lzEndpoint = lzEndpoint_;
    }

    /**
     * @notice Allows users to borrow a specific `amount` of the reserve underlying asset into the destination chain.
     * @dev The borrowers should already provide supplied enough collateral and delegate borrowing power to this contract
     * on the corresponding debt token (StableDebtToken or VariableDebtToken).
     * @param asset The address of the underlying asset to borrow.
     * @param amount The amount to be borrowed.
     * @param interestRateMode The interest rate mode at which the user wants to borrow: 1 for Stable, 2 for Variable.
     * @param dstEndpointId The destination endpoint ID.
     * @param receiver The address of the recipient.
     */
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint32 dstEndpointId,
        address receiver
    ) external payable {
        if (asset == address(0)) revert ZeroAddress();
        if (dstEndpointId == FLOW_ENDPOINT_ID) revert NotCrossChain();

        address stargateOFT = stargateOFTs[asset];
        _onlyWhitelisted(stargateOFT);

        IPool(POOL).borrow(
            asset,
            amount,
            interestRateMode,
            0,
            msg.sender
        );

        bytes memory composeMsg = new bytes(0);
        (
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        ) = Helpers.prepareSendParams(stargateOFT, dstEndpointId, amount, receiver, composeMsg);

        IERC20(asset).approve(stargateOFT, amount);
        IStargate(stargateOFT).sendToken{ value: msg.value }(sendParam, messagingFee, msg.sender);

        emit Borrow(msg.sender, asset, stargateOFT, amount, dstEndpointId, receiver);
    }

    /**
     * @notice Withdraws an `amount` of underlying asset from the reserve to the destination chain.
     * @param asset The address of the underlying asset to withdraw.
     * @param mAsset The address of the mToken to burn.
     * @param amount The underlying amount to be withdrawn.
     *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
     * @param dstEndpointId The destination endpoint ID.
     * @param receiver The address that will receive the underlying, same as msg.sender if the user
     *   wants to receive it on his own wallet, or a different address if the beneficiary is a
     *   different wallet
     */
    function withdraw(
        address asset,
        address mAsset,
        uint256 amount,
        uint32 dstEndpointId,
        address receiver
    ) external payable {
        if (asset == address(0)) revert ZeroAddress();
        if (dstEndpointId == FLOW_ENDPOINT_ID) revert NotCrossChain();

        address stargateOFT = stargateOFTs[asset];
        _onlyWhitelisted(stargateOFT);

        IERC20(mAsset).safeTransferFrom(msg.sender, address(this), amount);
        IPool(POOL).withdraw(
            asset,
            amount,
            address(this)
        );

        bytes memory composeMsg = new bytes(0);
        (
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        ) = Helpers.prepareSendParams(stargateOFT, dstEndpointId, amount, receiver, composeMsg);

        IERC20(asset).approve(stargateOFT, amount);
        IStargate(stargateOFT).sendToken{ value: msg.value }(sendParam, messagingFee, msg.sender);

        emit Withdraw(msg.sender, asset, stargateOFT, amount, dstEndpointId, receiver);
    }

    /// @inheritdoc ILayerZeroComposer
    function lzCompose(
        address from,
        bytes32,
        bytes calldata message,
        address,
        bytes calldata 
    ) external payable {
        if (msg.sender != lzEndpoint) revert NotLzEndpoint();
        if (!isWhitelisted[from]) revert NotStargateOFT();

        uint256 amount = OFTComposeMsgCodec.amountLD(message);
        bytes memory composeMessage = OFTComposeMsgCodec.composeMsg(message);

        (
            uint8 functionType,
            address user,
            uint256 interestRateMode
        ) = abi.decode(composeMessage, (uint8, address, uint256));

        address asset = IStargate(from).token();
        IERC20(asset).approve(POOL, amount);
        if (functionType == uint8(FunctionType.Supply)) {
            IPool(POOL).supply(
                asset,
                amount,
                user,
                0
            );
            emit Supply(user, asset, from, amount);

        } else if (functionType == uint8(FunctionType.Repay)) {
            IPool(POOL).repay(
                asset,
                amount,
                interestRateMode,
                user
            );
            emit Repay(user, asset, from, amount, interestRateMode);
        }
    }
}
