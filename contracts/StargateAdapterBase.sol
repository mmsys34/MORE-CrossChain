// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IStargate, SendParam, MessagingFee } from "./interfaces/IStargate.sol";
import { Helpers } from "./libraries/Helpers.sol";

abstract contract StargateAdapterBase is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    enum FunctionType {
        Supply,
        Repay
    }

    error ZeroAddress();
    error NotSupportedAsset();

    event SetStargateOFTs(address indexed asset, address indexed stargateOFT, bool isActive);
    event RecoverToken(address indexed token, address indexed to, uint256 amount);

    uint32 internal constant FLOW_ENDPOINT_ID = 30336;

    mapping(address => address) public stargateOFTs;
    mapping(address => bool) public isWhitelisted;

    function __StargateAdapterBase_init() internal onlyInitializing {}

    /**
     * @notice Sets Stargate OFT addresses for each underlying asset to be borrowed.
     * @param asset The address of underlying asset. This can be address(0), which is native token.
     * @param stargateOFT The address of stargate OFT.
     * @param isActive The flag to indicate whether the specified stargate OFT is supported.
     */
    function setStargateOFTs(
        address asset,
        address stargateOFT,
        bool isActive
    ) external onlyOwner {
        if (stargateOFT == address(0)) revert ZeroAddress();
        stargateOFTs[asset] = stargateOFT;
        isWhitelisted[stargateOFT] = isActive;

        emit SetStargateOFTs(asset, stargateOFT, isActive);
    }

    /// @dev Recovers the token sent to this contract by mistake
    /// @dev only owner
    /// @param token the token to recover. if 0x0 then it is native token
    /// @param to the address to send the token to
    /// @param amount the amount to send
    function recoverToken(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(to, amount);

        emit RecoverToken(token, to, amount);
    }

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

    /// @dev Checks whether the specified stargate OFT is whitelisted or not.
    function _onlyWhitelisted(address stargateOFT) internal view {
        if (stargateOFT == address(0) || !isWhitelisted[stargateOFT]) {
            revert NotSupportedAsset();
        }
    }
}
