// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from  "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPool } from "../contracts/interfaces/IPool.sol";
import { ICreditDelegationToken } from "../contracts/interfaces/ICreditDelegationToken.sol";
import { StargateIntegrationMainchain } from "../contracts/StargateIntegrationMainchain.sol";

contract StargateIntegrationMainchainTest is Test {
    // the identifiers of the forks
    uint256 flowFork;

    event SetStargateAddresses(
        address indexed asset,
        address indexed stargateOFT,
        address indexed tokenMessaging
    );

    event Borrow(
        address indexed borrower,
        address indexed asset,
        address indexed stargateOFT,
        uint256 amount,
        uint32 dstEndpointId,
        address receiver
    );

    address usdc = 0xF1815bd50389c46847f0Bda824eC8da914045D14;
    address stargateOFTUSDC = 0xAF54BE5B6eEc24d6BFACf1cce4eaF680A8239398;
    address variableDebtUSDC = 0xbD6e2ae2c8A0e3AA8f694C795cb0E7cbB6199d44;

    address weth = 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590;
    address stargateOFTWETH = 0x45f1A95A4D3f3836523F5c83673c797f4d4d263B;
    address variableDebtWETH = 0x152F64483b8253E426ad4b6F600096f73b727D84;

    address tokenMessagingOnETH = 0x45A01E4e04F14f7A4a6702c74187c5F6222033cd;

    address user = 0x86C1F1B7D3e91603D7f96871F108121878F483cd;
    StargateIntegrationMainchain public stargateIntegration;

    address public deployer;

    address internal constant POOL = 0xbC92aaC2DBBF42215248B5688eB3D3d2b32F2c8d;
    uint32 internal constant FLOW_ENDPOINT_ID = 30336;
    uint256 internal constant INTEREST_RATE_MODE = 2; // only variable mode
    
    function setUp() public {
        deployer = vm.addr(1);

        flowFork = vm.createSelectFork(vm.rpcUrl("flow"));
        // deploy StargateIntegration
        vm.prank(deployer);
        stargateIntegration = new StargateIntegrationMainchain();

        deal(usdc, user, 100e6);
        vm.startPrank(user);
        IERC20(usdc).approve(POOL, 50e6);
        IPool(POOL).supply(
            usdc,
            50e6,
            user,
            0
        );
    }

    function test_BorrowUSDC() public {
        uint256 amount = 1e6;
        uint32 dstEndpointId = 30110; // Arbitrum
        uint256 estimateFee = stargateIntegration.estimateFee(
            stargateOFTUSDC,
            dstEndpointId,
            amount,
            user,
            new bytes(0)
        );

        _revertCases(usdc, amount, dstEndpointId, estimateFee);

        _setStargateAddresses();

        vm.startPrank(user);
        ICreditDelegationToken(variableDebtUSDC).approveDelegation(address(stargateIntegration), amount);
        vm.expectEmit(true, true, true, true);
        emit Borrow(user, usdc, stargateOFTUSDC, amount, dstEndpointId, user);
        stargateIntegration.borrow{value: estimateFee}(usdc, amount, INTEREST_RATE_MODE, dstEndpointId, user);
    }

    function test_BorrowWETH() public {
        uint256 amount = 3e14;
        uint32 dstEndpointId = 30101; // Mainnet
        uint256 estimateFee = stargateIntegration.estimateFee(
            stargateOFTWETH,
            dstEndpointId,
            amount,
            user,
            new bytes(0)
        );
        _revertCases(weth, amount, dstEndpointId, estimateFee);

        _setStargateAddresses();

        vm.startPrank(user);
        ICreditDelegationToken(variableDebtWETH).approveDelegation(address(stargateIntegration), amount);

        vm.expectEmit(true, true, true, true);
        emit Borrow(user, weth, stargateOFTWETH, amount, dstEndpointId, user);
        stargateIntegration.borrow{value: estimateFee}(weth, amount, INTEREST_RATE_MODE, dstEndpointId, user);
    }

    function _revertCases(address asset, uint256 amount, uint32 dstEndpointId, uint256 estimateFee) internal {
        vm.expectRevert(abi.encodeWithSignature("NotCrossChain()"));
        stargateIntegration.borrow{value: estimateFee}(asset, amount, INTEREST_RATE_MODE, FLOW_ENDPOINT_ID, user);

        vm.expectRevert(abi.encodeWithSignature("NotSupportedAsset()"));
        stargateIntegration.borrow{value: estimateFee}(asset, amount, INTEREST_RATE_MODE, dstEndpointId, user);
    }

    function _setStargateAddresses() internal {
        vm.startPrank(deployer);

        vm.expectEmit(true, true, false, false);
        emit SetStargateAddresses(usdc, stargateOFTUSDC, tokenMessagingOnETH);
        stargateIntegration.setStargateAddresses(usdc, stargateOFTUSDC, tokenMessagingOnETH);
        
        vm.expectEmit(true, true, false, false);
        emit SetStargateAddresses(weth, stargateOFTWETH, tokenMessagingOnETH);
        stargateIntegration.setStargateAddresses(weth, stargateOFTWETH, tokenMessagingOnETH);
        vm.stopPrank();
    }
}
