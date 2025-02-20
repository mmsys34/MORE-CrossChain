// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from  "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ICreditDelegationToken } from "../contracts/interfaces/ICreditDelegationToken.sol";
import { StargateIntegration } from "../contracts/StargateIntegration.sol";

contract StargateIntegrationTest is Test {
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

    address USDC = 0xF1815bd50389c46847f0Bda824eC8da914045D14;
    address stargateOFTUSDC = 0xAF54BE5B6eEc24d6BFACf1cce4eaF680A8239398;
    address variableDebtUSDC = 0xbD6e2ae2c8A0e3AA8f694C795cb0E7cbB6199d44;

    address WETH = 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590;
    address stargateOFTWETH = 0x45f1A95A4D3f3836523F5c83673c797f4d4d263B;
    address variableDebtWETH = 0x152F64483b8253E426ad4b6F600096f73b727D84;

    address user = 0x86C1F1B7D3e91603D7f96871F108121878F483cd;
    StargateIntegration public stargateIntegration;
    address public deployer;

    uint32 internal constant FLOW_ENDPOINT_ID = 30336;
    uint256 internal constant INTEREST_RATE_MODE = 2; // only variable mode
    
    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("flow"));

        deployer = vm.addr(1);
        // deploy StargateIntegration
        vm.prank(deployer);
        stargateIntegration = new StargateIntegration();
    }

    function test_BorrowUSDC() public {
        uint256 amount = 2000000;
        uint32 dstEndpointId = 30110; // Arbitrum
        uint256 estimateFee = stargateIntegration.estimateFee(
            stargateOFTUSDC,
            dstEndpointId,
            amount,
            user
        );

        _revertCases(USDC, amount, dstEndpointId, estimateFee);

        _setStargateOFTs();

        vm.startPrank(user);
        ICreditDelegationToken(variableDebtUSDC).approveDelegation(address(stargateIntegration), amount);
        vm.expectEmit(true, true, true, true);
        emit Borrow(user, USDC, stargateOFTUSDC, amount, dstEndpointId, user);
        stargateIntegration.borrow{value: estimateFee}(USDC, amount, INTEREST_RATE_MODE, dstEndpointId, user);
    }

    function test_BorrowWETH() public {
        uint256 amount = 7e14;
        uint32 dstEndpointId = 30101; // Mainnet
        uint256 estimateFee = stargateIntegration.estimateFee(
            stargateOFTWETH,
            dstEndpointId,
            amount,
            user
        );
        _revertCases(WETH, amount, dstEndpointId, estimateFee);

        _setStargateOFTs();

        vm.startPrank(user);
        ICreditDelegationToken(variableDebtWETH).approveDelegation(address(stargateIntegration), amount);

        vm.expectEmit(true, true, true, true);
        emit Borrow(user, WETH, stargateOFTWETH, amount, dstEndpointId, user);
        stargateIntegration.borrow{value: estimateFee}(WETH, amount, INTEREST_RATE_MODE, dstEndpointId, user);
    }

    function _revertCases(address asset, uint256 amount, uint32 dstEndpointId, uint256 estimateFee) internal {
        vm.expectRevert(abi.encodeWithSignature("SameChainBorrow()"));
        stargateIntegration.borrow{value: estimateFee}(asset, amount, INTEREST_RATE_MODE, FLOW_ENDPOINT_ID, user);

        vm.expectRevert(abi.encodeWithSignature("NotSupportedAsset()"));
        stargateIntegration.borrow{value: estimateFee}(asset, amount, INTEREST_RATE_MODE, dstEndpointId, user);
    }

    function _setStargateOFTs() internal {
        vm.startPrank(deployer);

        vm.expectEmit(true, true, false, false);
        emit SetStargateOFTs(USDC, stargateOFTUSDC);
        stargateIntegration.setStargateOFTs(USDC, stargateOFTUSDC);
        
        vm.expectEmit(true, true, false, false);
        emit SetStargateOFTs(WETH, stargateOFTWETH);
        stargateIntegration.setStargateOFTs(WETH, stargateOFTWETH);
        vm.stopPrank();
    }
}
