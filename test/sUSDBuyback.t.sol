// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {sUSDBuyback} from "../src/sUSDBuyback.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface TokenState {
    function associatedContract() view external returns (address);

    function balanceOf(address) view external returns (uint256);

    function setBalanceOf(address, uint256) external;
}

contract sUSDBuybackTest is Test {
    sUSDBuyback buyback;
    string OP_MAINNET_RPC = vm.envString("OP_MAINNET_RPC");
    address sUSD = 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9;
    address USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    TokenState sUSDTokenState = TokenState(0x92bAc115d89cA17fd02Ed9357CEcA32842ACB4c2);
    address feeAddress = 0xfeEFEEfeefEeFeefEEFEEfEeFeefEEFeeFEEFEeF;
    address redeemer = address(69);

    function setUp() public {
        vm.createSelectFork(OP_MAINNET_RPC);
        buyback = new sUSDBuyback(msg.sender);
    }

    function mintsUSD(address who, uint256 amount) internal {
        uint256 before = sUSDTokenState.balanceOf(who);
        vm.prank(sUSDTokenState.associatedContract());
        sUSDTokenState.setBalanceOf(who, before + amount);
    }

    function test_exchange() public {
        mintsUSD(redeemer, 100e18);
        deal(USDC, address(buyback), 100e6);
        vm.startPrank(redeemer);
        uint256 before = IERC20(sUSD).balanceOf(feeAddress);
        IERC20(sUSD).approve(address(buyback), 100e18);
        buyback.exchange(100e6);
        assertEq(IERC20(sUSD).balanceOf(redeemer), 0);
        assertEq(IERC20(USDC).balanceOf(address(buyback)), 0);
        assertEq(IERC20(USDC).balanceOf(redeemer), 100e6);
        assertEq(IERC20(sUSD).balanceOf(feeAddress), before + 100e18);
    }

    function test_rugUSDC() public {
        deal(USDC, address(buyback), 100e6);
        vm.expectRevert();
        buyback.recoverERC20(USDC);
    }

    function test_rugOtherToken() public {
        mintsUSD(address(buyback), 1e18);
        buyback.recoverERC20(sUSD);
        assertEq(IERC20(sUSD).balanceOf(address(buyback)), 0);
        assertEq(IERC20(sUSD).balanceOf(buyback.owner()), 1e18);
    }

    function test_notOwnerRug() public {
        mintsUSD(address(buyback), 1e18);
        vm.prank(address(555));
        vm.expectRevert();
        buyback.recoverERC20(sUSD);
    }

    function test_notEnoughsUSDBalance() public {
        mintsUSD(redeemer, 99e18);
        deal(USDC, address(buyback), 100e6);
        vm.startPrank(redeemer);
        IERC20(sUSD).approve(address(buyback), 100e18);
        vm.expectRevert();
        buyback.exchange(100e6);
    }

    function test_notEnoughUSDC() public {
        mintsUSD(redeemer, 100e18);
        deal(USDC, address(buyback), 99e6);
        vm.startPrank(redeemer);
        IERC20(sUSD).approve(address(buyback), 100e18);
        vm.expectRevert();
        buyback.exchange(100e6);
    }
}
