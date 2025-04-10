// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { DlnOrderLib } from "./DlnOrderLib.sol";

library Helpers {
    function prepareOrder(
        address maker,
        address giveAsset,
        uint256 giveAmount,
        address takeAsset,
        uint256 takeAmount,
        uint256 takeChainId,
        address receiver,
        bytes memory externalCall
    ) internal pure returns (DlnOrderLib.OrderCreation memory) {
        return DlnOrderLib.OrderCreation({
            giveTokenAddress: giveAsset,
            giveAmount: giveAmount,
            takeTokenAddress: addressToBytes(takeAsset),
            takeAmount: takeAmount,
            takeChainId: takeChainId,
            receiverDst: addressToBytes(receiver),
            givePatchAuthoritySrc: maker,
            orderAuthorityAddressDst: addressToBytes(maker),
            allowedTakerDst: "",
            externalCall: externalCall,
            allowedCancelBeneficiarySrc: ""
        });
    }

    /**
     * @dev Converts an address to bytes.
     * @param addr The address to convert.
     * @return The bytes representation of the address.
     */
    function addressToBytes(address addr) internal pure returns (bytes memory) {
        return abi.encodePacked(addr);
    }
}
