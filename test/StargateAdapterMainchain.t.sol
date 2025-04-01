// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from  "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { TransparentUpgradeableProxy } from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPool } from "../contracts/interfaces/IPool.sol";
import { ICreditDelegationToken } from "../contracts/interfaces/ICreditDelegationToken.sol";
import { StargateAdapterMainchain } from "../contracts/StargateAdapterMainchain.sol";

contract StargateAdapterMainchainTest is Test {
    // the identifiers of the forks
    uint256 flowFork;

    event SetStargateOFTs(
        address indexed asset,
        address indexed stargateOFT,
        bool isActive
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
    address mStgUSDC = 0x49c6b2799aF2Db7404b930F24471dD961CFE18b7;
    address variableDebtUSDC = 0xbD6e2ae2c8A0e3AA8f694C795cb0E7cbB6199d44;

    address weth = 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590;
    address stargateOFTWETH = 0x45f1A95A4D3f3836523F5c83673c797f4d4d263B;
    address mStgWETH = 0xaD412305cF8aD9545759466F3d889438598F773F;
    address variableDebtWETH = 0x152F64483b8253E426ad4b6F600096f73b727D84;

    address lzEndpointOnFlow = 0xcb566e3B6934Fa77258d68ea18E931fa75e1aaAa;

    address user = 0x86C1F1B7D3e91603D7f96871F108121878F483cd;
    StargateAdapterMainchain public stargateAdapter;

    address public deployer;

    address internal constant POOL = 0xbC92aaC2DBBF42215248B5688eB3D3d2b32F2c8d;
    uint32 internal constant FLOW_ENDPOINT_ID = 30336;
    uint256 internal constant INTEREST_RATE_MODE = 2; // only variable mode
    
    function setUp() public {
        deployer = vm.addr(1);

        flowFork = vm.createSelectFork(vm.rpcUrl("flow"));
        // deploy StargateAdapter Proxy
        address implStargateAdapter = address(new StargateAdapterMainchain());
        address proxyStargateAdapter = address(new TransparentUpgradeableProxy(implStargateAdapter, deployer, ""));
        stargateAdapter = StargateAdapterMainchain(proxyStargateAdapter);
        vm.prank(deployer);
        stargateAdapter.initialize(lzEndpointOnFlow);

        deal(user, 1 ether);
        deal(usdc, user, 100e6);
        deal(weth, user, 1e18);

        vm.startPrank(user);
        IERC20(usdc).approve(POOL, 50e6);
        IPool(POOL).supply(
            usdc,
            50e6,
            user,
            0
        );

        IERC20(weth).approve(POOL, 1e18);
        IPool(POOL).supply(
            weth,
            1e18,
            user,
            0
        );
    }

    function test_BorrowUSDC() public {
        uint256 amount = 1e6;
        uint32 dstEndpointId = 30110; // Arbitrum

        _revertCases(usdc, amount, dstEndpointId, 1 ether);

        _setStargateOFTs();

        uint256 estimateFee = stargateAdapter.estimateFee(
            usdc,
            dstEndpointId,
            amount,
            user,
            new bytes(0)
        );

        vm.startPrank(user);
        ICreditDelegationToken(variableDebtUSDC).approveDelegation(address(stargateAdapter), amount);
        vm.expectEmit(true, true, true, true);
        emit Borrow(user, usdc, stargateOFTUSDC, amount, dstEndpointId, user);
        stargateAdapter.borrow{value: estimateFee}(usdc, amount, INTEREST_RATE_MODE, dstEndpointId, user);
    }

    function test_BorrowWETH() public {
        uint256 amount = 3e14;
        uint32 dstEndpointId = 30101; // Mainnet
        _revertCases(weth, amount, dstEndpointId, 1 ether);

        _setStargateOFTs();

        uint256 estimateFee = stargateAdapter.estimateFee(
            weth,
            dstEndpointId,
            amount,
            user,
            new bytes(0)
        );

        vm.startPrank(user);
        ICreditDelegationToken(variableDebtWETH).approveDelegation(address(stargateAdapter), amount);

        vm.expectEmit(true, true, true, true);
        emit Borrow(user, weth, stargateOFTWETH, amount, dstEndpointId, user);
        stargateAdapter.borrow{value: estimateFee}(weth, amount, INTEREST_RATE_MODE, dstEndpointId, user);
    }

    function test_WithdrawUSDC() public {
        uint256 amountToWithdraw = 10e6;
        uint32 dstEndpointId = 30101; // Mainnet

        _revertCases(usdc, amountToWithdraw, dstEndpointId, 1 ether);

        _setStargateOFTs();

        uint256 estimateFee = stargateAdapter.estimateFee(
            usdc,
            dstEndpointId,
            amountToWithdraw,
            user,
            new bytes(0)
        );

        vm.startPrank(user);
        IERC20(mStgUSDC).approve(address(stargateAdapter), amountToWithdraw);
        stargateAdapter.withdraw{value: estimateFee}(usdc, mStgUSDC, amountToWithdraw, dstEndpointId, user);
    }

    function test_WithdrawETH() public {
        uint256 amountToWithdraw = 1e14;
        uint32 dstEndpointId = 30101; // Mainnet

        _setStargateOFTs();

        uint256 estimateFee = stargateAdapter.estimateFee(
            weth,
            dstEndpointId,
            amountToWithdraw,
            user,
            new bytes(0)
        );

        vm.startPrank(user);
        IERC20(mStgWETH).approve(address(stargateAdapter), amountToWithdraw);
        stargateAdapter.withdraw{value: estimateFee}(weth, mStgWETH, amountToWithdraw, dstEndpointId, user);
    }

    function _revertCases(address asset, uint256 amount, uint32 dstEndpointId, uint256 estimateFee) internal {
        vm.expectRevert(abi.encodeWithSignature("NotCrossChain()"));
        stargateAdapter.borrow{value: estimateFee}(asset, amount, INTEREST_RATE_MODE, FLOW_ENDPOINT_ID, user);

        vm.expectRevert(abi.encodeWithSignature("NotSupportedAsset()"));
        stargateAdapter.borrow{value: estimateFee}(asset, amount, INTEREST_RATE_MODE, dstEndpointId, user);
    }

    function _setStargateOFTs() internal {
        vm.startPrank(deployer);

        vm.expectEmit(true, true, false, false);
        emit SetStargateOFTs(usdc, stargateOFTUSDC, true);
        stargateAdapter.setStargateOFTs(usdc, stargateOFTUSDC, true);
        
        vm.expectEmit(true, true, false, false);
        emit SetStargateOFTs(weth, stargateOFTWETH, true);
        stargateAdapter.setStargateOFTs(weth, stargateOFTWETH, true);
        vm.stopPrank();
    }
}
