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
        debridgeAdapter.initialize(dlnSource, proxyDebridgeAdapterMainchain);
    
        deal(user, 1 ether);
        deal(usdc, user, 100e6);
    }

    function test_SupplyUSDC() public {
        uint256 amount = 1e6;
        uint256 protocolFee = IDlnSource(dlnSource).globalFixedNativeFee();

        vm.startPrank(user);
        IERC20(usdc).approve(address(debridgeAdapter), amount);
        debridgeAdapter.supply{value: protocolFee}(usdc, amount);
    }

    function test_RepayUSDC() public {
        uint256 amount = 1e6;
        uint256 protocolFee = IDlnSource(dlnSource).globalFixedNativeFee();

        vm.startPrank(user);
        IERC20(usdc).approve(address(debridgeAdapter), amount);
        debridgeAdapter.repay{value: protocolFee}(usdc, amount, 2);
    }
}
