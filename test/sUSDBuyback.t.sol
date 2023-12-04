// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {sUSDBuyback} from "../src/sUSDBuyback.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract CounterTest is Test {
    sUSDBuyback buyback;
    string OP_MAINNET_RPC = vm.envString("OP_MAINNET_RPC");
    address sUSD = 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9;
    address USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address sUSDTokenState = 0x92bAc115d89cA17fd02Ed9357CEcA32842ACB4c2;
    address feeAddress = 0xfeEFEEfeefEeFeefEEFEEfEeFeefEEFeeFEEFEeF;
    address redeemer = address(69);

    function setUp() public {
        vm.createSelectFork(OP_MAINNET_RPC);
        buyback = new sUSDBuyback(sUSD ,USDC);
    }

    function test_exchange() public {
        deal(sUSDTokenState, redeemer, 100e18);
        deal(USDC, address(buyback), 100e6);
        vm.startPrank(redeemer);
        uint256 before = IERC20(sUSD).balanceOf(feeAddress);
        IERC20(sUSD).approve(address(buyback), 100e18);
        buyback.exchange(100e18);
        assertEq(IERC20(sUSD).balanceOf(redeemer), 0);
        assertEq(IERC20(USDC).balanceOf(address(buyback)), 0);
        assertEq(IERC20(USDC).balanceOf(redeemer), 100e6);
        assertEq(IERC20(sUSD).balanceOf(feeAddress), before + 100e18);
    }

    function test_invalidConstructor() public {
        vm.expectRevert();
        buyback = new sUSDBuyback(USDC, sUSD);
    }

    function test_rugUSDC() public {
        deal(USDC, address(buyback), 100e6);
        vm.expectRevert();
        buyback.recoverERC20(USDC);
    }

    function test_rugOtherToken() public {
        deal(sUSDTokenState, address(buyback), 1e18);
        buyback.recoverERC20(sUSD);
        assertEq(IERC20(sUSD).balanceOf(address(buyback)), 0);
    }

    function test_notOwnerRug() public {
        deal(sUSDTokenState, address(buyback), 1e18);
        vm.prank(address(555));
        vm.expectRevert();
        buyback.recoverERC20(sUSD);
    }

    function test_notApproved() public {
        deal(sUSDTokenState, redeemer, 100e18);
        deal(USDC, address(buyback), 100e6);
        vm.startPrank(redeemer);
        vm.expectRevert();
        buyback.exchange(100e18);
    }

    function test_notEnoughsUSDBalance() public {
        deal(sUSDTokenState, redeemer, 99e18);
        deal(USDC, address(buyback), 100e6);
        vm.startPrank(redeemer);
        IERC20(sUSD).approve(address(buyback), 100e18);
        vm.expectRevert();
        buyback.exchange(100e18);
    }

    function test_notEnoughUSDC() public {
        deal(sUSDTokenState, redeemer, 100e18);
        deal(USDC, address(buyback), 99e6);
        vm.startPrank(redeemer);
        IERC20(sUSD).approve(address(buyback), 100e18);
        vm.expectRevert();
        buyback.exchange(100e18);
    }

    function test_dust() public {
        deal(sUSDTokenState, redeemer, 100e18 + 1);
        deal(USDC, address(buyback), 100e6);
        vm.startPrank(redeemer);
        IERC20(sUSD).approve(address(buyback), 100e18);
        vm.expectRevert();
        buyback.exchange(100e18 + 1);
    }
}
