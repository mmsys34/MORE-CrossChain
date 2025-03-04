// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./StargateAdapterBase.sol";

contract StargateAdapterSidechain is StargateAdapterBase {
    using SafeERC20 for IERC20;

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

    address public stgAdapterMainchain;
    address public weth;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address stgAdapterMainchain_, address weth_) public initializer {
        __Ownable_init(msg.sender);
        __StargateAdapterBase_init();

        stgAdapterMainchain = stgAdapterMainchain_;
        weth = weth_;
    }

    /**
     * @notice Supplies an `amount` of underlying asset into the reserve pool from a different chain.
     * @dev Always send `msg.value` for the bridge. It must be the same as the estimated fee.
     * @param asset The address of the underlying asset to be bridged from the source chain.
     * @param amount The amount to be supplied.
     */
    function supply(
        address asset,
        uint256 amount
    ) external payable {
        if (asset == address(0)) revert ZeroAddress();
        address stargateOFT = stargateOFTs[asset];
        _onlyWhitelisted(stargateOFT);

        bytes memory composeMsg = abi.encode(uint8(FunctionType.Supply), msg.sender, 0);
        (
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        ) = Helpers.prepareSendParams(stargateOFT, FLOW_ENDPOINT_ID, amount, stgAdapterMainchain, composeMsg);

        if (asset != weth) {
            IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
            IERC20(asset).approve(stargateOFT, amount);
        }
        IStargate(stargateOFT).sendToken{ value: msg.value }(sendParam, messagingFee, msg.sender);

        emit Supply(msg.sender, asset, stargateOFT, amount, FLOW_ENDPOINT_ID);
    }

    /**
     * @notice Repays a borrowed `amount` on a specific reserve, burning the equivalent debt tokens owned
     * @dev Always send `msg.value` for the bridge. It must be the same as the estimated fee.
     * @param asset The address of the borrowed underlying asset on the source chain.
     * @param amount The amount to repay. Send the value type(uint256).max in order to repay the whole debt
     * for `asset` on the specific `debtMode`.
     * @param interestRateMode The interest rate mode at of the debt the user wants to repay:
     * 1 for Stable, 2 for Variable.
     */
    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external payable {
        if (asset == address(0)) revert ZeroAddress();
        address stargateOFT = stargateOFTs[asset];
        _onlyWhitelisted(stargateOFT);

        bytes memory composeMsg = abi.encode(uint8(FunctionType.Repay), msg.sender, interestRateMode);
        (
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        ) = Helpers.prepareSendParams(stargateOFT, FLOW_ENDPOINT_ID, amount, stgAdapterMainchain, composeMsg);

        if (asset != weth) {
            IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
            IERC20(asset).approve(stargateOFT, amount);
        }
        IStargate(stargateOFT).sendToken{ value: msg.value }(sendParam, messagingFee, msg.sender);

        emit Repay(msg.sender, asset, stargateOFT, amount, interestRateMode, FLOW_ENDPOINT_ID);
    }
}
