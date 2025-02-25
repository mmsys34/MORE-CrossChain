// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./StargateIntegrationBase.sol";

contract StargateIntegrationSidechain is StargateIntegrationBase {
    event SetStargateOFTs(
        address indexed asset,
        address indexed stargateOFT
    );

    event Supply(
        address indexed supplier,
        address indexed asset,
        address indexed stargateOFT,
        uint256 amount,
        uint32 dstEndpointId
    );

    event Repay(
        address indexed repayer,
        address indexed asset,
        address indexed stargateOFT,
        uint256 amount,
        uint256 interestRateMode,
        uint32 dstEndpointId
    );

    error ZeroAddress();
    error NotSupportedAsset();

    address internal immutable stgIntegrationMainchain;
    mapping(address =>  address) public stargateOFTs;

    /// @notice Constructor
    constructor(address stgIntegrationMainchain_) StargateIntegrationBase(msg.sender) {
        stgIntegrationMainchain = stgIntegrationMainchain_;
    }

    /**
     * @notice Sets Stargate OFT addresses for each underlying asset to be borrowed.
     * @param asset The underlying asset to be borrowed.
     * @param stargateOFT The stargate OFT address.
     */
    function setStargateOFTs(
        address asset,
        address stargateOFT
    ) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        stargateOFTs[asset] = stargateOFT;

        emit SetStargateOFTs(asset, stargateOFT);
    }

    /**
     * @notice Supplies an `amount` of underlying asset into the reserve pool from a different chain.
     * @dev Always send `msg.value` for the bridge. It must be the same as the estimated fee.
     * @param asset The address of the underlying asset to be bridged from the source chain.
     * @param assetOnDst The address of the underlying asset to supply on the destination chain.
     * @param amount The amount to be supplied.
     */
    function supply(
        address asset,
        address assetOnDst,
        uint256 amount
    ) external payable {
        address stargateOFT = stargateOFTs[asset];
        if (stargateOFT == address(0)) revert NotSupportedAsset();

        bytes memory composeMsg = abi.encode(uint8(FunctionType.Supply), msg.sender, assetOnDst, 0);
        (
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        ) = Helpers.prepareSendParams(stargateOFT, FLOW_ENDPOINT_ID, amount, stgIntegrationMainchain, composeMsg);

        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(stargateOFT, amount);
        IStargate(stargateOFT).sendToken{ value: msg.value }(sendParam, messagingFee, msg.sender);

        emit Supply(msg.sender, asset, stargateOFT, amount, FLOW_ENDPOINT_ID);
    }

    /**
     * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
     * @dev Always send `msg.value` for the bridge. It must be the same as the estimated fee.
     * @param asset The address of the borrowed underlying asset on the source chain.
     * @param assetOnDst The address of the underlying asset to repay on the destination chain.
     * @param amount The amount to repay. Send the value type(uint256).max in order to repay the whole debt
     * for `asset` on the specific `debtMode`.
     * @param interestRateMode The interest rate mode at of the debt the user wants to repay:
     * 1 for Stable, 2 for Variable.
     */
    function repay(
        address asset,
        address assetOnDst,
        uint256 amount,
        uint256 interestRateMode
    ) external payable {
        address stargateOFT = stargateOFTs[asset];
        if (stargateOFT == address(0)) revert NotSupportedAsset();

        bytes memory composeMsg = abi.encode(uint8(FunctionType.Repay), msg.sender, assetOnDst, interestRateMode);
        (
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        ) = Helpers.prepareSendParams(stargateOFT, FLOW_ENDPOINT_ID, amount, stgIntegrationMainchain, composeMsg);

        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(stargateOFT, amount);
        IStargate(stargateOFT).sendToken{ value: msg.value }(sendParam, messagingFee, msg.sender);

        emit Repay(msg.sender, asset, stargateOFT, amount, interestRateMode, FLOW_ENDPOINT_ID);
    }
}
