// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../Gum.sol";

interface CheatCodes {
    function prank(address) external;

    function startPrank(address, address) external;

    function stopPrank() external;
}

contract GumTest is DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Gum gumContract;

    address MARKETPLACE_ADDRESS = address(1);
    address STAKING_ADDRESS = address(2);
    address USER_ADDRESS = address(3);
    address SPENDER_ADDRESS = address(4);
    address RANDO_ADDRESS = address(5);
    address NEW_MARKETPLACE_ADDRESS = address(6);
    address ANOTHER_APPROVED_ADDRESS = address(7);
    address NEW_STAKING_ADDRESS = address(8);

    function setUp() public {
        gumContract = new Gum(MARKETPLACE_ADDRESS, STAKING_ADDRESS);
        gumContract.mint(USER_ADDRESS, 1_000_000);
    }

    function testMarketplaceTransfer() public {
        cheats.prank(USER_ADDRESS);
        bool success = gumContract.transfer(MARKETPLACE_ADDRESS, 100);
        assertTrue(success);
    }

    function testFailTransfer() public {
        cheats.prank(USER_ADDRESS);
        bool success = gumContract.transfer(RANDO_ADDRESS, 100);
        assertTrue(success);
    }

    function testFailAddToTransferAllowList() public {
        cheats.prank(RANDO_ADDRESS);
        gumContract.updateTransferAllowList(NEW_MARKETPLACE_ADDRESS, 0);
    }

    function testFailRemoveFromTransferAllowList() public {
        cheats.prank(RANDO_ADDRESS);
        gumContract.updateTransferAllowList(MARKETPLACE_ADDRESS, 1);
    }

    function testAddToTransferAllowList() public {
        // get allow list length before
        uint256 transferAllowListLengthBefore = gumContract
            .getTransferAllowListLength();
        assertEq(transferAllowListLengthBefore, 1);

        // add new address
        gumContract.updateTransferAllowList(NEW_MARKETPLACE_ADDRESS, 0);

        // get list length after
        uint256 transferAllowListLengthAfter = gumContract
            .getTransferAllowListLength();
        assertEq(transferAllowListLengthAfter, 2);

        // check for address
        address transferAllowListAtIndexZero = gumContract
            .getTransferAllowListAtIndex(0);
        address transferAllowListAtIndexOne = gumContract
            .getTransferAllowListAtIndex(1);
        bool listIncludesAddress = transferAllowListAtIndexZero ==
            NEW_MARKETPLACE_ADDRESS ||
            transferAllowListAtIndexOne == NEW_MARKETPLACE_ADDRESS;
        assertTrue(listIncludesAddress);
    }

    function testRemoveFromTransferAllowList() public {
        // setup: add address
        gumContract.updateTransferAllowList(NEW_MARKETPLACE_ADDRESS, 0);

        // get allow list length before
        uint256 transferAllowListLengthBefore = gumContract
            .getTransferAllowListLength();
        assertEq(transferAllowListLengthBefore, 2);

        // remove address
        gumContract.updateTransferAllowList(NEW_MARKETPLACE_ADDRESS, 1);

        // get allow list length after
        uint256 transferAllowListLengthAfter = gumContract
            .getTransferAllowListLength();
        assertEq(transferAllowListLengthAfter, 1);
    }

    function testTransferAllowListFlow() public {
        // add addresses
        gumContract.updateTransferAllowList(NEW_MARKETPLACE_ADDRESS, 0);
        gumContract.updateTransferAllowList(ANOTHER_APPROVED_ADDRESS, 0);

        // transfer to them
        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);
        bool successOne = gumContract.transfer(NEW_MARKETPLACE_ADDRESS, 69);
        assertTrue(successOne);
        bool successTwo = gumContract.transfer(ANOTHER_APPROVED_ADDRESS, 420);
        assertTrue(successTwo);
        bool successThree = gumContract.transfer(MARKETPLACE_ADDRESS, 666);
        assertTrue(successThree);
        cheats.stopPrank();

        // remove them
        gumContract.updateTransferAllowList(NEW_MARKETPLACE_ADDRESS, 1);
        gumContract.updateTransferAllowList(ANOTHER_APPROVED_ADDRESS, 1);

        // check that they're gone
        uint256 transferAllowListLength = gumContract
            .getTransferAllowListLength();
        assertEq(transferAllowListLength, 1);
        address transferAllowListAtIndexZero = gumContract
            .getTransferAllowListAtIndex(0);
        assertEq(transferAllowListAtIndexZero, MARKETPLACE_ADDRESS);
    }

    function testFailTransferAllowListFlow() public {
        // add an address
        gumContract.updateTransferAllowList(NEW_MARKETPLACE_ADDRESS, 0);

        // transfer to it
        cheats.prank(USER_ADDRESS);
        bool success = gumContract.transfer(NEW_MARKETPLACE_ADDRESS, 100);
        assertTrue(success);

        // remove it
        gumContract.updateTransferAllowList(NEW_MARKETPLACE_ADDRESS, 1);

        // check that it's gone
        uint256 transferAllowListLength = gumContract
            .getTransferAllowListLength();
        assertEq(transferAllowListLength, 1);
        address transferAllowListAtIndexZero = gumContract
            .getTransferAllowListAtIndex(0);
        assertEq(transferAllowListAtIndexZero, MARKETPLACE_ADDRESS);

        // fail to transfer
        gumContract.transfer(NEW_MARKETPLACE_ADDRESS, 101);
    }

    function testOwnerMint() public {
        gumContract.mint(USER_ADDRESS, 100);
    }

    function testStakingMint() public {
        cheats.prank(STAKING_ADDRESS);
        gumContract.mint(USER_ADDRESS, 100);
    }

    function testFailMint() public {
        cheats.prank(RANDO_ADDRESS);
        gumContract.mint(USER_ADDRESS, 100);
    }

    function testUpdateStaking() public {
        address oldStaking = gumContract.staking();
        assertEq(oldStaking, STAKING_ADDRESS);
        gumContract.updateStaking(NEW_STAKING_ADDRESS);
        address newStaking = gumContract.staking();
        assertEq(newStaking, NEW_STAKING_ADDRESS);
    }

    function testFailUpdateStaking() public {
        cheats.prank(RANDO_ADDRESS);
        gumContract.updateStaking(NEW_STAKING_ADDRESS);
    }

    function testMarketplaceTransferFrom() public {
        cheats.prank(USER_ADDRESS);
        gumContract.approve(SPENDER_ADDRESS, 100);
        cheats.prank(SPENDER_ADDRESS);
        gumContract.transferFrom(USER_ADDRESS, MARKETPLACE_ADDRESS, 100);
    }

    function testFailTransferFrom() public {
        cheats.prank(USER_ADDRESS);
        gumContract.approve(SPENDER_ADDRESS, 100);
        cheats.prank(SPENDER_ADDRESS);
        gumContract.transferFrom(USER_ADDRESS, RANDO_ADDRESS, 100);
    }
}
