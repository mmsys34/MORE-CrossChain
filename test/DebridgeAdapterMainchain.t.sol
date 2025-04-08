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
import { DebridgeAdapterMainchain } from "../contracts/DebridgeAdapterMainchain.sol";

contract DebridgeAdapterMainchainTest is Test {
    address internal constant POOL = 0xbC92aaC2DBBF42215248B5688eB3D3d2b32F2c8d;
    uint256 internal constant INTEREST_RATE_MODE = 2; // only variable mode

    address wethOnFlow = 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590;
    address usdcOnFlow = 0xF1815bd50389c46847f0Bda824eC8da914045D14;
    address variableDebtUSDC = 0xbD6e2ae2c8A0e3AA8f694C795cb0E7cbB6199d44;
    address mUSDC = 0x49c6b2799aF2Db7404b930F24471dD961CFE18b7;

    address usdcOnArb = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address dlnSource = 0xeF4fB24aD0916217251F553c0596F8Edc630EB66;
    address dlnExternalCallAdapter = 0xE93356b0b87c71A7F4957DCEBEd05BefA8cB624a;

    address user = 0x86C1F1B7D3e91603D7f96871F108121878F483cd;

    DebridgeAdapterMainchain public debridgeAdapter;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("flow"));
        
        // deploy StargateAdapter Proxy
        address implementation = address(new DebridgeAdapterMainchain());
        address proxy = address(new TransparentUpgradeableProxy(implementation, address(this), ""));
        debridgeAdapter = DebridgeAdapterMainchain(proxy);
        debridgeAdapter.initialize(dlnSource, dlnExternalCallAdapter);
    
        deal(wethOnFlow, user, 1e18);
        deal(usdcOnFlow, user, 100e6);

        vm.startPrank(user);
        IERC20(wethOnFlow).approve(POOL, 1e18);
        IPool(POOL).supply(
            wethOnFlow,
            1e18,
            user,
            0
        );

        IERC20(usdcOnFlow).approve(POOL, 10e6);
        IPool(POOL).supply(
            usdcOnFlow,
            10e6,
            user,
            0
        );
    }

    function test_BorrowUSDC() public {
        uint256 takeChainId = 42161; // Arbitrum
        uint256 amount = 10e6;
        // getting the protocol fee
        uint256 protocolFee = IDlnSource(dlnSource).globalFixedNativeFee();

        vm.startPrank(user);
        ICreditDelegationToken(variableDebtUSDC).approveDelegation(address(debridgeAdapter), amount);

        bytes32 orderId = debridgeAdapter.borrow{value: protocolFee}(
            usdcOnFlow,
            amount,
            INTEREST_RATE_MODE,
            usdcOnArb,
            takeChainId,
            user
        );
        vm.stopPrank();
    }

    function test_WithdrawUSDC() public {
        uint256 takeChainId = 42161; // Arbitrum
        uint256 amount = 10e6;
        // getting the protocol fee
        uint256 protocolFee = IDlnSource(dlnSource).globalFixedNativeFee();

        vm.startPrank(user);
        IERC20(mUSDC).approve(address(debridgeAdapter), amount);
        bytes32 orderId = debridgeAdapter.withdraw{value: protocolFee}(
            usdcOnFlow,
            mUSDC,
            amount,
            usdcOnArb,
            takeChainId,
            user
        );
        vm.stopPrank();
    }
}
