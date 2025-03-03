// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from  "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { TransparentUpgradeableProxy } from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICreditDelegationToken } from "../contracts/interfaces/ICreditDelegationToken.sol";
import { StargateAdapterMainchain } from "../contracts/StargateAdapterMainchain.sol";
import { StargateAdapterSidechain } from "../contracts/StargateAdapterSidechain.sol";

contract StargateAdapterSidechainTest is Test {
    uint32 internal constant FLOW_ENDPOINT_ID = 30336;

    StargateAdapterSidechain public stargateAdapterSidechain;

    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address stgOFTUSDC = 0xc026395860Db2d07ee33e05fE50ed7bD583189C7;
    address stgOFTNative = 0x77b2043768d28E9C9aB44E1aBfC95944bcE57931;

    address user = 0x86C1F1B7D3e91603D7f96871F108121878F483cd;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("flow"));
        address implStgAdapterMainchain = address(new StargateAdapterMainchain());
        address proxyStgAdapterMainchain = address(new TransparentUpgradeableProxy(implStgAdapterMainchain, address(this), ""));

        vm.createSelectFork(vm.rpcUrl("ethereum"));

        address implStgAdapterSidechain = address(new StargateAdapterSidechain());
        address proxyStgAdapterSidechain  = address(new TransparentUpgradeableProxy(implStgAdapterSidechain, address(this), ""));
        stargateAdapterSidechain = StargateAdapterSidechain(proxyStgAdapterSidechain);
        stargateAdapterSidechain.initialize(address(proxyStgAdapterMainchain));

        stargateAdapterSidechain.setStargateOFTs(address(0), stgOFTNative, true);
        stargateAdapterSidechain.setStargateOFTs(usdc, stgOFTUSDC, true);
    
        deal(user, 1 ether);
        deal(address(usdc), user, 100e6);
    }

    function test_SupplyUSDC() public {
        uint256 amount = 1e6;
        bytes memory composeMsg = abi.encode(0, user, 0);
        uint256 estimateFee = stargateAdapterSidechain.estimateFee(
            stgOFTUSDC,
            FLOW_ENDPOINT_ID,
            amount,
            stargateAdapterSidechain.stgAdapterMainchain(),
            composeMsg
        );

        vm.startPrank(user);
        IERC20(usdc).approve(address(stargateAdapterSidechain), amount);
        stargateAdapterSidechain.supply{value: estimateFee}(usdc, amount);
    }

    function test_SupplyETH() public {
        uint256 amount = 1e17;
        bytes memory composeMsg = abi.encode(0, user, 0);

        uint256 estimateFee = stargateAdapterSidechain.estimateFee(
            stgOFTNative,
            FLOW_ENDPOINT_ID,
            amount,
            stargateAdapterSidechain.stgAdapterMainchain(),
            composeMsg
        );

        vm.prank(user);
        stargateAdapterSidechain.supply{value: estimateFee}(address(0), amount);
    }

    function test_RepayUSDC() public {
        uint256 amount = 1e6;
        bytes memory composeMsg = abi.encode(1, msg.sender, 2);

        uint256 estimateFee = stargateAdapterSidechain.estimateFee(
            stgOFTUSDC,
            FLOW_ENDPOINT_ID,
            amount,
            stargateAdapterSidechain.stgAdapterMainchain(),
            composeMsg
        );

        vm.startPrank(user);
        IERC20(usdc).approve(address(stargateAdapterSidechain), amount);
        stargateAdapterSidechain.repay{value: estimateFee}(usdc, amount, 2);
    }

    function test_RepayWETH() public {
        uint256 amount = 1e15;
        bytes memory composeMsg = abi.encode(1, msg.sender, 2);

        uint256 estimateFee = stargateAdapterSidechain.estimateFee(
            stgOFTNative,
            FLOW_ENDPOINT_ID,
            amount,
            stargateAdapterSidechain.stgAdapterMainchain(),
            composeMsg
        );

        vm.prank(user);
        stargateAdapterSidechain.repay{value: estimateFee}(address(0), amount, 2);
    }
}
