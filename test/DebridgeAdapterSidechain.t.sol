// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from  "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { TransparentUpgradeableProxy } from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPool } from "../contracts/interfaces/IPool.sol";
import { ICreditDelegationToken } from "../contracts/interfaces/ICreditDelegationToken.sol";
import { IDlnSource } from "../contracts/interfaces/IDlnSource.sol";
import { DlnOrderLib } from "../contracts/libraries/DlnOrderLib.sol";
import { DebridgeAdapterSidechain } from "../contracts/DebridgeAdapterSidechain.sol";
import { DebridgeAdapterMainchain } from "../contracts/DebridgeAdapterMainchain.sol";

contract DebridgeAdapterSidechainTest is Test {
    address usdcOnFlow = 0xF1815bd50389c46847f0Bda824eC8da914045D14;
    address wethOnFlow = 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590;
    address swapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address dlnSource = 0xeF4fB24aD0916217251F553c0596F8Edc630EB66;

    address user = 0x86C1F1B7D3e91603D7f96871F108121878F483cd;

    DebridgeAdapterSidechain public debridgeAdapter;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("flow"));
        address implDebridgeAdapterMainchain = address(new DebridgeAdapterMainchain());
        address proxyDebridgeAdapterMainchain = address(new TransparentUpgradeableProxy(implDebridgeAdapterMainchain, address(this), ""));
    
        vm.createSelectFork(vm.rpcUrl("ethereum"));
        // deploy StargateAdapter Proxy
        address implementation = address(new DebridgeAdapterSidechain());
        address proxy = address(new TransparentUpgradeableProxy(implementation, address(this), ""));
        debridgeAdapter = DebridgeAdapterSidechain(proxy);
        debridgeAdapter.initialize(dlnSource, 0xD797764D0b5A339488BFC944fF0105aA14200811, swapRouter, usdc);
    
        deal(user, 1 ether);
        deal(weth, user, 1e18);
        deal(usdc, user, 100e6);
    }

    function test_SupplyUSDC() public {
        uint256 amount = 1e6;
        uint256 takeAmount = uint256(819361) * 995 / 1000; // 0.5% slippage
        uint256 protocolFee = IDlnSource(dlnSource).globalFixedNativeFee();

        vm.startPrank(user);
        IERC20(usdc).approve(address(debridgeAdapter), amount);
        debridgeAdapter.supply{value: protocolFee}(usdc, amount, usdcOnFlow, takeAmount);
    }

    function test_SupplyWETH() public {
        uint256 amount = 1e16;
        uint256 takeAmount = uint256(9779871707688550) * 995 / 1000; // 0.5% slippage
        uint256 protocolFee = IDlnSource(dlnSource).globalFixedNativeFee();

        vm.startPrank(user);
        IERC20(weth).approve(address(debridgeAdapter), amount);
        debridgeAdapter.supply{value: protocolFee}(weth, amount, wethOnFlow, takeAmount);
    }

    function test_RepayUSDC() public {
        uint256 amount = 1e6;
        uint256 takeAmount = uint256(819361) * 995 / 1000; // 0.5% slippage
        uint256 protocolFee = IDlnSource(dlnSource).globalFixedNativeFee();

        vm.startPrank(user);
        IERC20(usdc).approve(address(debridgeAdapter), amount);
        debridgeAdapter.repay{value: protocolFee}(usdc, amount, 2, usdcOnFlow, takeAmount);
    }

    function test_RepayWETH() public {
        uint256 amount = 1e16;
        uint256 takeAmount = uint256(9779871707688550);
        uint256 protocolFee = IDlnSource(dlnSource).globalFixedNativeFee();

        vm.startPrank(user);
        IERC20(weth).approve(address(debridgeAdapter), amount);
        debridgeAdapter.repay{value: protocolFee}(weth, amount, 2, wethOnFlow, takeAmount);
    }
}
