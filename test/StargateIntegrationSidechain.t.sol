// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from  "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICreditDelegationToken } from "../contracts/interfaces/ICreditDelegationToken.sol";
import { StargateIntegrationMainchain } from "../contracts/StargateIntegrationMainchain.sol";
import { StargateIntegrationSidechain } from "../contracts/StargateIntegrationSidechain.sol";

contract StargateIntegrationSidechainTest is Test {
    uint32 internal constant FLOW_ENDPOINT_ID = 30336;

    StargateIntegrationSidechain public stargateIntegration;

    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address stgOFTUSDC = 0xc026395860Db2d07ee33e05fE50ed7bD583189C7;

    address usdcOnFlow = 0xF1815bd50389c46847f0Bda824eC8da914045D14;

    address user = 0x86C1F1B7D3e91603D7f96871F108121878F483cd;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("flow"));
        StargateIntegrationMainchain stargateIntegrationMainchain = new StargateIntegrationMainchain();

        vm.createSelectFork(vm.rpcUrl("ethereum"));

        stargateIntegration = new StargateIntegrationSidechain(address(stargateIntegrationMainchain));
    }

    function test_RepayUSDC() public {
        uint256 amount = 1e6;
        stargateIntegration.setStargateOFTs(usdc, stgOFTUSDC);

        deal(user, 1 ether);
        deal(address(usdc), user, 100e6);
        vm.startPrank(user);

        bytes memory composeMsg = abi.encode(1, msg.sender, usdcOnFlow, 2);
        uint256 estimateFee = stargateIntegration.estimateFee(
            stgOFTUSDC,
            FLOW_ENDPOINT_ID,
            amount,
            address(stargateIntegration),
            composeMsg
        );

        IERC20(usdc).approve(address(stargateIntegration), amount);

        stargateIntegration.repay{value: estimateFee}(
            usdc, usdcOnFlow, amount, 2
        );
    }
}
