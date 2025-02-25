// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ILayerZeroComposer } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import { IPool } from "./interfaces/IPool.sol";
import "./StargateIntegrationBase.sol";

contract StargateIntegrationMainchain is ILayerZeroComposer, Ownable, StargateIntegrationBase {
    event SetStargateAddresses(
        address indexed asset,
        address indexed stargateOFT,
        address indexed lzEndpoint
    );

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

    error ZeroAddress();
    error NotCrossChain();
    error NotSupportedAsset();
    error NotLZEndpoint();

    address internal constant POOL = 0xbC92aaC2DBBF42215248B5688eB3D3d2b32F2c8d;

    mapping(address =>  address) public stargateOFTs;
    mapping(address =>  address) public lzEndpoints;

    /// @notice Constructor
    constructor() StargateIntegrationBase(msg.sender) {}

    /**
     * @notice Sets Stargate OFT addresses for each underlying asset to be borrowed.
     * @param asset The underlying asset to be borrowed.
     * @param stargateOFT The stargate OFT address.
     */
    function setStargateAddresses(
        address asset,
        address stargateOFT,
        address lzEndpoint
    ) external onlyOwner {
        if (asset == address(0) || stargateOFT == address(0)) revert ZeroAddress();
        stargateOFTs[asset] = stargateOFT;
        lzEndpoints[stargateOFT] = lzEndpoint;

        emit SetStargateAddresses(asset, stargateOFT, lzEndpoint);
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
        if (dstEndpointId == FLOW_ENDPOINT_ID) revert NotCrossChain();

        address stargateOFT = stargateOFTs[asset];
        if (stargateOFT == address(0)) revert NotSupportedAsset();

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
        if (dstEndpointId == FLOW_ENDPOINT_ID) revert NotCrossChain();

        address stargateOFT = stargateOFTs[asset];
        if (stargateOFT == address(0)) revert NotSupportedAsset();

        IERC20(mAsset).transferFrom(msg.sender, address(this), amount);
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
        if (msg.sender != lzEndpoints[from]) revert NotLZEndpoint();
        uint256 amount = OFTComposeMsgCodec.amountLD(message);
        bytes memory composeMessage = OFTComposeMsgCodec.composeMsg(message);

        (
            uint8 functionType,
            address user,
            address asset,
            uint256 interestRateMode
        ) = abi.decode(composeMessage, (uint8, address, address, uint256));

        if (functionType == uint8(FunctionType.Supply)) {
            IERC20(asset).approve(POOL, amount);
            IPool(POOL).supply(
                asset,
                amount,
                user,
                0
            );

            emit Supply(user, asset, from, amount);

        } else if (functionType == uint8(FunctionType.Repay)) {
            IERC20(asset).approve(POOL, amount);
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
