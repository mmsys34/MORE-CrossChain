// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IStargate, SendParam, MessagingFee } from "./interfaces/IStargate.sol";
import { Helpers } from "./libraries/Helpers.sol";

abstract contract StargateAdapterBase is OwnableUpgradeable {
    enum FunctionType {
        Supply,
        Repay
    }

    uint32 internal constant FLOW_ENDPOINT_ID = 30336;

    function __StargateAdapterBase_init() internal onlyInitializing {}

    /** 
     * @notice Returns the estimated gas amount required to bridge a specific `amount` of the borrowed asset
     * to the destination chain.
     * @param stargateOFT The stargate OFT address.
     * @param dstEndpointId The destination endpoint ID.
     * @param amount The amount to be borrowed.
     * @param receiver The address of the recipient.
     */
    function estimateFee(
        address stargateOFT,
        uint32 dstEndpointId,
        uint256 amount,
        address receiver,
        bytes memory composeMsg
    ) external view returns (uint256) {
        (SendParam memory sendParam, MessagingFee memory messagingFee) = Helpers.prepareSendParams(
            stargateOFT,
            dstEndpointId,
            amount,
            receiver,
            composeMsg
        );
        
        uint256 valueToSend = messagingFee.nativeFee;

        if (IStargate(stargateOFT).token() == address(0x0)) {
            valueToSend += sendParam.amountLD;
        }

        return valueToSend;
    }
}
