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

    address lzEndpointOnFlow = 0xcb566e3B6934Fa77258d68ea18E931fa75e1aaAa;

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

    function test_LzCompose() public {
        address stgIntegration = 0xafD01A1D038f51DE3Aa65e45869Eb85511c86E5D;
        address mStgUSDC = 0x49c6b2799aF2Db7404b930F24471dD961CFE18b7;

        _setStargateAddresses();

        vm.startPrank(lzEndpointOnFlow);
        bytes memory message = vm.parseBytes("0x000000000000008a0000759500000000000000000000000000000000000000000000000000000000000974a200000000000000000000000068bd14c251e35c1af9be0f80d4aa66053953a9fd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000086c1f1b7d3e91603d7f96871f108121878f483cd000000000000000000000000f1815bd50389c46847f0bda824ec8da914045d140000000000000000000000000000000000000000000000000000000000000000");
        StargateIntegrationMainchain(stgIntegration).lzCompose(
            0xAF54BE5B6eEc24d6BFACf1cce4eaF680A8239398,
            0x99e95f3f9e20d70d0102fe45877c1a89e8c8aad76b70c413acdf201ae4ac48b7,
            message,
            0xa20DB4Ffe74A31D17fc24BD32a7DD7555441058e,
            new bytes(0)
        );
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
        emit SetStargateAddresses(usdc, stargateOFTUSDC, lzEndpointOnFlow);
        stargateIntegration.setStargateAddresses(usdc, stargateOFTUSDC, lzEndpointOnFlow);
        
        vm.expectEmit(true, true, false, false);
        emit SetStargateAddresses(weth, stargateOFTWETH, lzEndpointOnFlow);
        stargateIntegration.setStargateAddresses(weth, stargateOFTWETH, lzEndpointOnFlow);
        vm.stopPrank();
    }
}
