// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IPool } from "./interfaces/IPool.sol";
import { IStargate, SendParam, MessagingFee, OFTReceipt } from "./interfaces/IStargate.sol";

contract StargateIntegration is Ownable {
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

    error ZeroAddress();
    error SameChainBorrow();
    error NotSupportedAsset();
    
    address internal constant POOL = 0xbC92aaC2DBBF42215248B5688eB3D3d2b32F2c8d;
    uint32 internal constant FLOW_ENDPOINT_ID = 30336;

    mapping(address =>  address) public stargateOFTs;

    /// @notice Constructor
    constructor() Ownable(msg.sender) {}

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
        if (dstEndpointId == FLOW_ENDPOINT_ID) revert SameChainBorrow();

        address stargateOFT = stargateOFTs[asset];
        if (stargateOFT == address(0)) revert NotSupportedAsset();

        IPool(POOL).borrow(
            asset,
            amount,
            interestRateMode,
            0,
            msg.sender
        );

        IERC20(asset).approve(stargateOFT, amount);
        (
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        ) = _prepareSendParams(stargateOFT, dstEndpointId, amount, receiver);

        IStargate(stargateOFT).sendToken{ value: msg.value }(sendParam, messagingFee, msg.sender);

        emit Borrow(msg.sender, asset, stargateOFT, amount, dstEndpointId, receiver);
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
        address receiver
    ) external view returns (uint256) {
        (, MessagingFee memory messagingFee) = _prepareSendParams(
            stargateOFT,
            dstEndpointId,
            amount,
            receiver
        );
        
        return messagingFee.nativeFee;
    }

    /** 
     * @dev Prepares arguments for token bridge.
     * @param stargateOFT The stargate OFT address.
     * @param dstEndpointId The destination endpoint ID.
     * @param amount The amount to be borrowed.
     * @param receiver The address of the recipient.
     */
    function _prepareSendParams(
        address stargateOFT,
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
