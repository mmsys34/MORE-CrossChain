// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./StargateIntegrationBase.sol";

contract StargateIntegrationSidechain is StargateIntegrationBase {
    event SetStargateOFTs(
        address indexed asset,
        address indexed stargateOFT
    );

    event Borrow(
        address indexed borrower,
        address indexed asset,
        address indexed stargateOFT,
        uint256 amount,
        uint32 dstEndpointId,
        address receiver
    );

    event Repay(
        address indexed repayer,
        address indexed asset,
        uint256 amount
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
    }

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
    }
}
