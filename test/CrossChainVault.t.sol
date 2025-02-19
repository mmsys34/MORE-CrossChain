// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from  "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ICreditDelegationToken } from "../contracts/interfaces/ICreditDelegationToken.sol";
import { CrossChainVault } from "../contracts/CrossChainVault.sol";

contract CrossChainVaultTest is Test {
    address USDC = 0xF1815bd50389c46847f0Bda824eC8da914045D14;
    address StargateOFTUSDC = 0xAF54BE5B6eEc24d6BFACf1cce4eaF680A8239398;
    address variableDebtUSDC = 0xbD6e2ae2c8A0e3AA8f694C795cb0E7cbB6199d44;

    address user = 0x86C1F1B7D3e91603D7f96871F108121878F483cd;
    CrossChainVault public crossChainVault;
    address public deployer;
    
    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("flow"));

        deployer = vm.addr(1);
        // deploy CrossChainVault
        vm.startPrank(deployer);
        crossChainVault = new CrossChainVault();
        crossChainVault.setStargateOFTs(USDC, StargateOFTUSDC);
        vm.stopPrank();
    }

    function test_Borrow() public {
        uint256 amount = 2000000;
        uint256 interestRateMode = 2;
        uint32 dstEndpointId = 30110;
        uint256 estimateFee = crossChainVault.estimateFee(
            StargateOFTUSDC,
            dstEndpointId,
            amount,
            user
        );

        vm.startPrank(user);
        ICreditDelegationToken(variableDebtUSDC).approveDelegation(address(crossChainVault), amount);
        crossChainVault.borrow{value: estimateFee}(USDC, amount, interestRateMode, dstEndpointId, user);
    }
}
