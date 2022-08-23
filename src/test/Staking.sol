// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./console.sol";
import "ds-test/test.sol";
import "../Gum.sol";
import "../Staking.sol";

interface CheatCodes {
    function prank(address) external;

    function roll(uint256) external;

    function startPrank(address, address) external;

    function stopPrank() external;
}

interface IBGK {
    function approve(address to, uint256 tokenId) external;

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool approved);

    function ownerOf(uint256 tokenId) external view returns (address);

    function setApprovalForAll(address operator, bool _approved) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function balanceOf(address owner) external view returns (uint256 balance);
}

interface IBGP {
    function approve(address to, uint256 tokenId) external;

    function ownerOf(uint256 tokenId) external view returns (address);

    function setApprovalForAll(address operator, bool _approved) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function balanceOf(address owner) external view returns (uint256 balance);
}

contract StakingTest is DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Gum gumContract;
    Staking stakingContract;
    IBGK kids;
    IBGP pups;

    uint256[] internal kidsIds = new uint256[](12);
    uint256[] internal pupsIds = new uint256[](12);

    address USER_ADDRESS = address(1);
    address TRANSFER_ADDRESS = address(2);
    address RANDO_ADDRESS = address(3);
    address TEMP_STAKING_ADDRESS = address(4);
    address USER_ADDRESS_TWO = address(5);

    address BGK_ADDR = address(0xa5ae87B40076745895BB7387011ca8DE5fde37E0);
    address BGP_ADDR = address(0x86e9C5ad3D4b5519DA2D2C19F5c71bAa5Ef40933);
    address WHALE = address(0x521bC9Bb5Ab741658e48eF578D291aEe05DbA358);

    function setUp() public {
        gumContract = new Gum(TEMP_STAKING_ADDRESS);
        stakingContract = new Staking(address(gumContract));
        gumContract.updateStaking(address(stakingContract));

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

        kids = IBGK(BGK_ADDR);
        cheats.prank(WHALE);
        kids.setApprovalForAll(TRANSFER_ADDRESS, true);

        cheats.startPrank(TRANSFER_ADDRESS, TRANSFER_ADDRESS);

        for (uint256 i = 0; i < 12; i++) {
            kids.safeTransferFrom(WHALE, USER_ADDRESS, kidsIds[i]);
        }

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

        pups = IBGP(BGP_ADDR);
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

        cheats.startPrank(USER_ADDRESS_TWO, USER_ADDRESS_TWO);
        kids.setApprovalForAll(address(stakingContract), true);
        pups.setApprovalForAll(address(stakingContract), true);
        cheats.stopPrank();

        stakingContract.start();
    }

    function getTokenOwner(uint8 contractId, uint256 tokenId)
        internal
        view
        returns (address)
    {
        if (contractId == 0) {
            return kids.ownerOf(tokenId);
        } else {
            return pups.ownerOf(tokenId);
        }
    }

    function testStartAndStop() public {
        bool isStartedOne = stakingContract.started();
        assertTrue(isStartedOne);
        stakingContract.stop();
        bool isStartedTwo = stakingContract.started();
        assertTrue(!isStartedTwo);
    }

    // don't let non-owner start contract
    function testFailStart() public {
        stakingContract.stop();
        cheats.startPrank(RANDO_ADDRESS, RANDO_ADDRESS);
        stakingContract.start();
        cheats.stopPrank();
    }

    // don't let non-owner stop contract
    function testFailStop() public {
        cheats.startPrank(RANDO_ADDRESS, RANDO_ADDRESS);
        stakingContract.stop();
        cheats.stopPrank();
    }

    function testUpdateGumToken() public {
        address newGumToken = address(6);
        stakingContract.updateGumToken(newGumToken);
        address updatedGumToken = stakingContract.gumToken();
        assertEq(newGumToken, updatedGumToken);
    }

    // don't let non-owner update gum token
    function testFailUpdateGumToken() public {
        cheats.startPrank(RANDO_ADDRESS, RANDO_ADDRESS);
        stakingContract.updateGumToken(address(6));
        cheats.stopPrank();
    }

    function testUpdateStakeRewardRate() public {
        uint256 newStakeRewardRate = 2;
        stakingContract.updateStakeRewardRate(newStakeRewardRate);
        uint256 updatedStakeRewardRate = stakingContract.stakeRewardRate();
        assertEq(newStakeRewardRate, updatedStakeRewardRate);
    }

    // don't let non-owner update stake reward rate
    function testFailUpdateStakeRewardRate() public {
        cheats.startPrank(RANDO_ADDRESS, RANDO_ADDRESS);
        stakingContract.updateStakeRewardRate(2);
        cheats.stopPrank();
    }

    function testDeposit() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = kidsIds[0];
        tokenIds[1] = kidsIds[1];
        tokenIds[2] = pupsIds[0];

        uint8[] memory bgContracts = new uint8[](3);
        bgContracts[0] = 0;
        bgContracts[1] = 0;
        bgContracts[2] = 1;

        for (uint256 i; i < tokenIds.length; i++) {
            address tokenOwner = getTokenOwner(bgContracts[i], tokenIds[i]);
            assertEq(tokenOwner, USER_ADDRESS);
        }

        cheats.prank(USER_ADDRESS);
        stakingContract.deposit(tokenIds, bgContracts);

        uint256[][2] memory deposits = stakingContract.depositsOf(USER_ADDRESS);
        assertEq(deposits[0][0], kidsIds[0]);
        assertEq(deposits[0][1], kidsIds[1]);
        assertEq(deposits[1][0], pupsIds[0]);

        for (uint256 i; i < tokenIds.length; i++) {
            address tokenOwner = getTokenOwner(bgContracts[i], tokenIds[i]);
            assertEq(tokenOwner, address(stakingContract));
        }
    }

    // don't let a user deposit a jpeg they don't own
    function testFailDeposit() public {
        uint256 someoneElsesToken = 1;

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = someoneElsesToken;

        uint8[] memory bgContracts = new uint8[](1);
        bgContracts[0] = 0;

        cheats.prank(USER_ADDRESS);
        stakingContract.deposit(tokenIds, bgContracts);
    }

    // don't let a user re-deposit a jpeg they've already staked
    function testFailRedeposit() public {
        // deposit a jpeg
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = pupsIds[7];

        uint8[] memory bgContracts = new uint8[](1);
        bgContracts[0] = 1;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);
        stakingContract.deposit(tokenIds, bgContracts);

        // wait
        cheats.roll(block.number + 7200);

        // try to redeposit
        stakingContract.deposit(tokenIds, bgContracts);

        cheats.stopPrank();
    }

    function testWithdraw() public {
        // deposit some jpegs
        uint256[] memory depositTokenIds = new uint256[](3);
        depositTokenIds[0] = kidsIds[2];
        depositTokenIds[1] = pupsIds[1];
        depositTokenIds[2] = pupsIds[2];

        uint8[] memory depositBgContracts = new uint8[](3);
        depositBgContracts[0] = 0;
        depositBgContracts[1] = 1;
        depositBgContracts[2] = 1;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);
        stakingContract.deposit(depositTokenIds, depositBgContracts);

        // withdraw one of the jpegs
        uint256[] memory firstWithdrawalTokenIds = new uint256[](1);
        firstWithdrawalTokenIds[0] = depositTokenIds[0];

        uint8[] memory firstWithdrawalBgContracts = new uint8[](1);
        firstWithdrawalBgContracts[0] = depositBgContracts[0];

        stakingContract.withdraw(
            firstWithdrawalTokenIds,
            firstWithdrawalBgContracts
        );

        // check that jpeg was returned to user
        address firstWithdrawalTokenOwner;
        if (firstWithdrawalBgContracts[0] == 0) {
            firstWithdrawalTokenOwner = kids.ownerOf(depositTokenIds[0]);
        } else {
            firstWithdrawalTokenOwner = pups.ownerOf(depositTokenIds[0]);
        }
        assertEq(firstWithdrawalTokenOwner, USER_ADDRESS);

        // check that other jpegs are still deposited
        uint256[][2] memory depositsAfterFirstWithdrawal = stakingContract
            .depositsOf(USER_ADDRESS);
        assertEq(depositsAfterFirstWithdrawal[1][0], depositTokenIds[1]);
        assertEq(depositsAfterFirstWithdrawal[1][1], depositTokenIds[2]);

        // withdraw the rest
        uint256[] memory secondWithdrawalTokenIds = new uint256[](2);
        secondWithdrawalTokenIds[0] = depositTokenIds[1];
        secondWithdrawalTokenIds[1] = depositTokenIds[2];

        uint8[] memory secondWithdrawalBgContracts = new uint8[](2);
        secondWithdrawalBgContracts[0] = depositBgContracts[1];
        secondWithdrawalBgContracts[1] = depositBgContracts[2];

        stakingContract.withdraw(
            secondWithdrawalTokenIds,
            secondWithdrawalBgContracts
        );

        // check that jpegs were returned to user
        for (uint256 i; i < secondWithdrawalTokenIds.length; i++) {
            address secondWithdrawalTokenOwner = getTokenOwner(
                secondWithdrawalBgContracts[i],
                secondWithdrawalTokenIds[i]
            );
            assertEq(secondWithdrawalTokenOwner, USER_ADDRESS);
        }

        cheats.stopPrank();
    }

    function testWithdrawWithRewards() public {
        // deposit some jpegs
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = kidsIds[2];
        tokenIds[1] = pupsIds[1];
        tokenIds[2] = pupsIds[2];

        uint8[] memory bgContracts = new uint8[](3);
        bgContracts[0] = 0;
        bgContracts[1] = 1;
        bgContracts[2] = 1;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);
        stakingContract.deposit(tokenIds, bgContracts);

        uint256 daysElapsed = 100;
        cheats.roll(block.number + 7200 * daysElapsed);

        stakingContract.withdraw(tokenIds, bgContracts);

        cheats.stopPrank();

        uint256 gumBalance = gumContract.balanceOf(USER_ADDRESS) / 10**18;
        assertEq(gumBalance, daysElapsed * tokenIds.length);
    }

    // don't let a user withdraw a jpeg that hasn't been deposited
    function testFailWithdraw() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint8[] memory bgContracts = new uint8[](1);
        bgContracts[0] = 0;

        stakingContract.withdraw(tokenIds, bgContracts);
    }

    function testCalculateRewards() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = kidsIds[0];
        tokenIds[1] = kidsIds[1];
        tokenIds[2] = pupsIds[0];

        uint8[] memory bgContracts = new uint8[](3);
        bgContracts[0] = 0;
        bgContracts[1] = 0;
        bgContracts[2] = 1;

        cheats.prank(USER_ADDRESS);
        stakingContract.deposit(tokenIds, bgContracts);

        // roll forward 14,400 block (~two days)
        cheats.roll(block.number + 14_400);

        uint256[] memory rewards = stakingContract.calculateRewards(
            USER_ADDRESS,
            tokenIds,
            bgContracts
        );

        assertEq(rewards[0], 2 * 10**18);
        assertEq(rewards[1], 2 * 10**18);
        assertEq(rewards[2], 2 * 10**18);

        // roll forward 3600 blocks (~half a day)
        // rewards will be unchanged
        cheats.roll(block.number + 3600);

        rewards = stakingContract.calculateRewards(
            USER_ADDRESS,
            tokenIds,
            bgContracts
        );

        assertEq(rewards[0], 2 * 10**18);
        assertEq(rewards[1], 2 * 10**18);
        assertEq(rewards[2], 2 * 10**18);

        // roll forward another half day
        cheats.roll(block.number + 3600);

        rewards = stakingContract.calculateRewards(
            USER_ADDRESS,
            tokenIds,
            bgContracts
        );

        assertEq(rewards[0], 3 * 10**18);
        assertEq(rewards[1], 3 * 10**18);
        assertEq(rewards[2], 3 * 10**18);
    }

    function testCalculateRewardsUnstaked() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = kidsIds[0];
        tokenIds[1] = kidsIds[1];
        tokenIds[2] = pupsIds[0];

        uint8[] memory bgContracts = new uint8[](3);
        bgContracts[0] = 0;
        bgContracts[1] = 0;
        bgContracts[2] = 1;

        // don't deposit the jpegs

        uint256[] memory rewards = stakingContract.calculateRewards(
            USER_ADDRESS,
            tokenIds,
            bgContracts
        );

        assertEq(rewards[0], 0);
        assertEq(rewards[1], 0);
        assertEq(rewards[2], 0);
    }

    function testClaimRewards() public {
        // TODO
    }

    // make sure that after claiming rewards, deposit block
    // for jpegs is updated
    function testReadDepositBlocks() public {
        // deposit some jpegs
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = kidsIds[2];
        tokenIds[1] = kidsIds[5];

        uint8[] memory bgContracts = new uint8[](2);
        bgContracts[0] = 0;
        bgContracts[1] = 0;

        cheats.prank(USER_ADDRESS);
        stakingContract.deposit(tokenIds, bgContracts);

        uint256 oldBlockNumber = block.number;
        uint256 newBlockNumber = oldBlockNumber + 7200 * 14;

        uint256 depositBlock = stakingContract.depositBlocks(
            Staking.BGContract(bgContracts[0]),
            tokenIds[0]
        );
        assertEq(depositBlock, oldBlockNumber);

        cheats.roll(newBlockNumber);

        cheats.prank(USER_ADDRESS);
        stakingContract.claimRewards();

        // deposit block should be updated for jpegs
        uint256 claimedDepositBlockOne = stakingContract.depositBlocks(
            Staking.BGContract(bgContracts[0]),
            tokenIds[0]
        );
        uint256 claimedDepositBlockTwo = stakingContract.depositBlocks(
            Staking.BGContract(bgContracts[1]),
            tokenIds[1]
        );
        assertEq(claimedDepositBlockOne, newBlockNumber);
        assertEq(claimedDepositBlockTwo, newBlockNumber);
    }
}
