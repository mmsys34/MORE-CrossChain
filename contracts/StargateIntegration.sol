// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IPool } from "./interfaces/IPool.sol";
import { IStargate, SendParam, MessagingFee, OFTReceipt } from "./interfaces/IStargate.sol";

contract StargateIntegration is Ownable {
    error ZeroAddress();
    error SameChainBorrow();
    error NotSupportedAsset();
    
    address internal constant POOL = 0xbC92aaC2DBBF42215248B5688eB3D3d2b32F2c8d;
    uint32 internal constant FLOW_ENDPOINT_ID = 30336;

    mapping(address =>  address) public stargateOFTs;

    constructor() Ownable(msg.sender) {}

    function setStargateOFTs(
        address asset,
        address stargate
    ) external onlyOwner {
        if (asset == address(0)) revert ZeroAddress();
        stargateOFTs[asset] = stargate;
    }

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint32 dstEndpointId,
        address receiver
    ) external payable {
        if (dstEndpointId == FLOW_ENDPOINT_ID) revert SameChainBorrow();

        address stargate = stargateOFTs[asset];
        if (stargate == address(0)) revert NotSupportedAsset();

        IPool(POOL).borrow(
            asset,
            amount,
            interestRateMode,
            0,
            msg.sender
        );

        IERC20(asset).approve(stargate, amount);
        (
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        ) = _prepareSendParams(stargate, dstEndpointId, amount, receiver);

        IStargate(stargate).sendToken{ value: msg.value }(sendParam, messagingFee, msg.sender);
    }

    function estimateFee(
        address stargate,
        uint32 dstEndpointId,
        uint256 amount,
        address receiver
    ) external view returns (uint256) {
        (, MessagingFee memory messagingFee) = _prepareSendParams(
            stargate,
            dstEndpointId,
            amount,
            receiver
        );
        
        return messagingFee.nativeFee;
    }

    function _prepareSendParams(
        address stargate,
        uint32 dstEndpointId,
        uint256 amount,
        address receiver
    ) internal view returns (SendParam memory sendParam, MessagingFee memory messagingFee) {
        sendParam = SendParam({
            dstEid: dstEndpointId, // Destination endpoint ID.
            to: addressToBytes32(receiver), // Recipient address.
            amountLD: amount, // Amount to send in local decimals.
            minAmountLD: amount, // Minimum amount to send in local decimals.
            extraOptions: new bytes(0), // Additional options supplied by the caller to be used in the LayerZero message.
            composeMsg: new bytes(0), // The composed message for the send() operation.
            oftCmd: "" // Taking a taxi mode
        });

        (, , OFTReceipt memory receipt) = IStargate(stargate).quoteOFT(sendParam);
        sendParam.minAmountLD = receipt.amountReceivedLD;

        // Fee in native gas and ZRO token.
        messagingFee = IStargate(stargate).quoteSend(sendParam, false);
    }

    /**
     * @dev Converts an address to bytes32.
     * @param _addr The address to convert.
     * @return The bytes32 representation of the address.
     */
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
