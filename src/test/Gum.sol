// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../Gum.sol";

interface CheatCodes {
    function prank(address) external;
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
    address NEW_STAKING_ADDRESS = address(7);

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

    function testUpdateMarketplace() public {
        address oldMarketplace = gumContract.marketplace();
        assertEq(oldMarketplace, MARKETPLACE_ADDRESS);
        gumContract.updateMarkeplace(NEW_MARKETPLACE_ADDRESS);
        address newMarketplace = gumContract.marketplace();
        assertEq(newMarketplace, NEW_MARKETPLACE_ADDRESS);
    }

    function testFailUpdateMarketplace() public {
        cheats.prank(RANDO_ADDRESS);
        gumContract.updateMarkeplace(NEW_MARKETPLACE_ADDRESS);
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
