// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { IStargate, SendParam, MessagingFee, OFTReceipt } from "../interfaces/IStargate.sol";

library Helpers {
    using OptionsBuilder for bytes;

    /** 
     * @dev Prepares arguments for token bridge.
     * @param stargateOFT The stargate OFT address.
     * @param dstEndpointId The destination endpoint ID.
     * @param amount The amount to be borrowed.
     * @param receiver The address of the recipient.
     */
    function prepareSendParams(
        address stargateOFT,
        uint32 dstEndpointId,
        uint256 amount,
        address receiver,
        bytes memory composeMsg
    ) internal view returns (SendParam memory sendParam, MessagingFee memory messagingFee) {
        bytes memory extraOptions = composeMsg.length > 0
        ? OptionsBuilder.newOptions().addExecutorLzComposeOption(0, 300_000, 0) // compose gas limit
        : bytes("");

        sendParam = SendParam({
            dstEid: dstEndpointId, // Destination endpoint ID.
            to: addressToBytes32(receiver), // Recipient address.
            amountLD: amount, // Amount to send in local decimals.
            minAmountLD: amount, // Minimum amount to send in local decimals.
            extraOptions: extraOptions, // Additional options supplied by the caller to be used in the LayerZero message.
            composeMsg: composeMsg, // The composed message for the send() operation.
            oftCmd: "" // Taking a taxi mode
        });

        (, , OFTReceipt memory receipt) = IStargate(stargateOFT).quoteOFT(sendParam);
        sendParam.minAmountLD = receipt.amountReceivedLD;

        // Fee in native gas and ZRO token.
        messagingFee = IStargate(stargateOFT).quoteSend(sendParam, false);
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
