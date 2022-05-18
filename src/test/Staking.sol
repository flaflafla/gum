// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./console.sol";
import "ds-test/test.sol";
import "../Staking.sol";

interface CheatCodes {
    function prank(address) external;

    function startPrank(address, address) external;

    function stopPrank() external;
}

interface BGK {
    function approve(address to, uint256 tokenId) external;

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool approved);

    function setApprovalForAll(address operator, bool _approved) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function balanceOf(address owner) external view returns (uint256 balance);
}

interface BGP {
    function approve(address to, uint256 tokenId) external;

    function setApprovalForAll(address operator, bool _approved) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function balanceOf(address owner) external view returns (uint256 balance);
}

contract GumTest is DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Staking stakingContract;
    BGK kids;
    BGP pups;

    address GUM_TOKEN = address(1);
    address USER_ADDRESS = address(2);
    address TRANSFER_ADDRESS = address(3);

    address BGK_ADDR = address(0xa5ae87B40076745895BB7387011ca8DE5fde37E0);
    address BGP_ADDR = address(0x86e9C5ad3D4b5519DA2D2C19F5c71bAa5Ef40933);
    address WHALE = address(0x521bC9Bb5Ab741658e48eF578D291aEe05DbA358);

    function setUp() public {
        stakingContract = new Staking(GUM_TOKEN);

        uint256[] memory kidsIds = new uint256[](12);
        kidsIds[0] = 4245;
        kidsIds[1] = 4224;
        kidsIds[2] = 579;
        kidsIds[3] = 8177;
        kidsIds[4] = 5824;
        kidsIds[5] = 6266;
        kidsIds[6] = 4395;
        kidsIds[7] = 6889;
        kidsIds[8] = 3340;
        kidsIds[9] = 1217;
        kidsIds[10] = 3486;
        kidsIds[11] = 2994;

        kids = BGK(BGK_ADDR);
        cheats.prank(WHALE);
        kids.setApprovalForAll(TRANSFER_ADDRESS, true);

        cheats.startPrank(TRANSFER_ADDRESS, TRANSFER_ADDRESS);

        for (uint256 i = 0; i < 12; i++) {
            kids.safeTransferFrom(WHALE, USER_ADDRESS, kidsIds[i]);
        }

        uint256[] memory pupsIds = new uint256[](12);
        pupsIds[0] = 9898;
        pupsIds[1] = 9003;
        pupsIds[2] = 9717;
        pupsIds[3] = 9014;
        pupsIds[4] = 2232;
        pupsIds[5] = 9837;
        pupsIds[6] = 3495;
        pupsIds[7] = 3494;
        pupsIds[8] = 3493;
        pupsIds[9] = 3492;
        pupsIds[10] = 3491;
        pupsIds[11] = 3490;

        pups = BGP(BGP_ADDR);
        cheats.prank(WHALE);
        pups.setApprovalForAll(TRANSFER_ADDRESS, true);

        for (uint256 i = 0; i < 12; i++) {
            pups.safeTransferFrom(WHALE, USER_ADDRESS, pupsIds[i]);
        }

        cheats.stopPrank();

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);
        kids.setApprovalForAll(address(stakingContract), true);
        pups.setApprovalForAll(address(stakingContract), true);
        cheats.stopPrank();
    }

    function testDeposit() public {
        stakingContract.start();

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 4245;
        tokenIds[1] = 4224;
        tokenIds[2] = 9898;

        uint8[] memory bgContracts = new uint8[](3);
        bgContracts[0] = 0;
        bgContracts[1] = 0;
        bgContracts[2] = 1;

        cheats.prank(USER_ADDRESS);
        stakingContract.deposit(tokenIds, bgContracts);

        uint256[][2] memory deposits = stakingContract.depositsOf(USER_ADDRESS);
        assertEq(deposits[0][0], 4245);
        assertEq(deposits[0][1], 4224);
        assertEq(deposits[1][0], 9898);
    }
}
