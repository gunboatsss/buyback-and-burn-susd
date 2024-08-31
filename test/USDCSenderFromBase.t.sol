// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {Test, console2} from "forge-std/Test.sol";
import {USDCSenderFromBase} from "src/USDCSenderFromBase.sol";

contract USDCSenderFromBaseTest is Test {
    address owner = address(555);
    address dest = address(69420);
    USDCSenderFromBase sender;

    event DepositForBurn(
        uint64 indexed nonce,
        address indexed burnToken,
        uint256 amount,
        address indexed depositor,
        bytes32 mintRecipient,
        uint32 destinationDomain,
        bytes32 destinationTokenMessenger,
        bytes32 destinationCaller
    );

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_MAINNET_RPC"));
        sender = new USDCSenderFromBase(owner, uint32(2), dest, 2e6, 1e6, 500000000000000000);
        deal(0x09d51516F38980035153a554c26Df3C6f51a23C3, address(sender), 1000e18);
    }

    function test_Send() public {
        emit DepositForBurn(
            69,
            0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            999e6,
            address(sender),
            addressToBytes32(dest),
            uint32(2),
            addressToBytes32(0x2B4069517957735bE00ceE0fadAE88a26365528f),
            bytes32(0)
        );
        vm.expectEmit(false, true, false, false);
        sender.send();
    }
    function addressToBytes32(address _x) private pure returns (bytes32) {
        return bytes32(uint256(uint160(_x)));
    }
}
