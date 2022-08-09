// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

// TODO: what happens if you lock for zero days?!?!?!?!?!??

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

    function testUpdateLockBoostRates() public {
        uint256 newLockBoostRate = 10_000_000_000;
        uint256 newLockBoostRateIndex = 0;
        stakingContract.updateLockBoostRates(
            newLockBoostRate,
            newLockBoostRateIndex
        );
        uint256 updatedLockBoostRate = stakingContract.lockBoostRates(
            newLockBoostRateIndex
        );
        assertEq(newLockBoostRate, updatedLockBoostRate);
    }

    // don't let non-owner update lock boost rates
    function testFailUpdateLockBoostRates() public {
        cheats.startPrank(RANDO_ADDRESS, RANDO_ADDRESS);
        stakingContract.updateLockBoostRates(69_420, 0);
        cheats.stopPrank();
    }

    function testUpdateLockDurationsConfig() public {
        uint256 newLockDuration = 12;
        uint256 newLockDurationIndex = 1;
        stakingContract.updateLockDurationsConfig(
            newLockDuration,
            newLockDurationIndex
        );
        uint256 updatedLockDuration = stakingContract.lockDurationsConfig(
            newLockDurationIndex
        );
        assertEq(newLockDuration, updatedLockDuration);
    }

    // don't let non-owner update the lock durations config
    function testFailUpdateLockDurationsConfig() public {
        cheats.startPrank(RANDO_ADDRESS, RANDO_ADDRESS);
        stakingContract.updateLockDurationsConfig(666, 2);
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

    // don't let a user re-deposit a jpeg they've already staked
    // (using `depositAndLock` function)
    function testFailRedepositAndLock() public {
        // deposit a jpeg
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = pupsIds[7];

        uint8[] memory bgContracts = new uint8[](1);
        bgContracts[0] = 1;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);
        stakingContract.deposit(tokenIds, bgContracts);

        // wait
        cheats.roll(block.number + 7200);

        uint256[] memory durations = new uint256[](1);
        durations[0] = 1;

        // try to redeposit and lock
        stakingContract.depositAndLock(tokenIds, durations, bgContracts);

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

    function testWithdrawLocked() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = kidsIds[2];
        tokenIds[1] = pupsIds[1];
        tokenIds[2] = pupsIds[2];

        uint8[] memory bgContracts = new uint8[](3);
        bgContracts[0] = 0;
        bgContracts[1] = 1;
        bgContracts[2] = 1;

        uint256[] memory durations = new uint256[](3);
        durations[0] = 1;
        durations[1] = 2;
        durations[2] = 3;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);

        // deposit and lock some jpegs
        stakingContract.depositAndLock(tokenIds, durations, bgContracts);

        uint256 duration = stakingContract.lockDurationsConfig(3);
        cheats.roll(block.number + 7200 * duration);

        stakingContract.withdraw(tokenIds, bgContracts);

        /*
               30 * 1.1
                    150
              90 * 1.25
                     90
            + 180 * 1.4
            -----------
                   ~637
        */
        uint256 gumBalance = gumContract.balanceOf(USER_ADDRESS);
        assertEq(gumBalance, 6375 * (10**17));

        cheats.stopPrank();
    }

    // don't let a user withdraw a jpeg whose lock hasn't expired
    function testFailWithdrawLocked() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = kidsIds[2];

        uint8[] memory bgContracts = new uint8[](1);
        bgContracts[0] = 0;

        uint256[] memory durations = new uint256[](1);
        durations[0] = 3;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);

        // deposit and lock a jpeg
        stakingContract.depositAndLock(tokenIds, durations, bgContracts);

        // roll forward, but not enough
        uint256 duration = stakingContract.lockDurationsConfig(2);
        cheats.roll(block.number + 7200 * duration);

        // try to withdraw the jpeg
        stakingContract.withdraw(tokenIds, bgContracts);
    }

    function testLock() public {
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

        // throw away the key
        uint256[] memory durations = new uint256[](3);
        durations[0] = 1;
        durations[1] = 2;
        durations[2] = 3;

        stakingContract.lock(tokenIds, durations, bgContracts);

        // check locksOf
        uint256[][2] memory locks = stakingContract.locksOf(USER_ADDRESS);
        assertEq(locks[0][0], tokenIds[0]);
        assertEq(locks[1][0], tokenIds[1]);
        assertEq(locks[1][1], tokenIds[2]);

        cheats.stopPrank();
    }

    // make sure it doesn't open a black hole or something
    // (actually make sure you can withdraw immediately)
    function testLockForZeroDays() public {
        // deposit a jpeg
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = kidsIds[10];

        uint8[] memory bgContracts = new uint8[](1);
        bgContracts[0] = 0;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);
        stakingContract.deposit(tokenIds, bgContracts);

        // cross the streams
        uint256[] memory durations = new uint256[](1);
        durations[0] = 0;

        stakingContract.lock(tokenIds, durations, bgContracts);

        // check locksOf
        uint256[][2] memory locks = stakingContract.locksOf(USER_ADDRESS);
        assertEq(locks[0][0], tokenIds[0]);

        // withdraw immediately
        stakingContract.withdraw(tokenIds, bgContracts);

        cheats.stopPrank();
    }

    // don't let a user lock jpegs that aren't deposited
    function testFailLock() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = kidsIds[2];
        tokenIds[1] = pupsIds[1];
        tokenIds[2] = pupsIds[2];

        uint8[] memory bgContracts = new uint8[](3);
        bgContracts[0] = 0;
        bgContracts[1] = 1;
        bgContracts[2] = 1;

        uint256[] memory durations = new uint256[](3);
        durations[0] = 1;
        durations[1] = 2;
        durations[2] = 3;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);

        stakingContract.lock(tokenIds, durations, bgContracts);
        cheats.stopPrank();
    }

    function testDepositAndLock() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = kidsIds[2];
        tokenIds[1] = pupsIds[1];
        tokenIds[2] = pupsIds[2];

        uint8[] memory bgContracts = new uint8[](3);
        bgContracts[0] = 0;
        bgContracts[1] = 1;
        bgContracts[2] = 1;

        uint256[] memory durations = new uint256[](3);
        durations[0] = 1;
        durations[1] = 2;
        durations[2] = 3;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);

        // deposit and lock some jpegs
        stakingContract.depositAndLock(tokenIds, durations, bgContracts);

        // check depositsOf
        uint256[][2] memory deposits = stakingContract.depositsOf(USER_ADDRESS);
        assertEq(deposits[0][0], tokenIds[0]);
        assertEq(deposits[1][0], tokenIds[1]);
        assertEq(deposits[1][1], tokenIds[2]);

        // check locksOf
        uint256[][2] memory locks = stakingContract.locksOf(USER_ADDRESS);
        assertEq(locks[0][0], tokenIds[0]);
        assertEq(locks[1][0], tokenIds[1]);
        assertEq(locks[1][1], tokenIds[2]);

        cheats.stopPrank();
    }

    // don't let a user deposit and lock jpegs they don't own
    function testFailDepositAndLock() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 666;

        uint8[] memory bgContracts = new uint8[](1);
        bgContracts[0] = 0;

        uint256[] memory durations = new uint256[](1);
        durations[0] = 1;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);

        stakingContract.depositAndLock(tokenIds, durations, bgContracts);

        cheats.stopPrank();
    }

    // don't let a user deposit and lock jpegs they've already deposited
    function testFailDepositAndLockAlreadyDeposited() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = pupsIds[9];

        uint8[] memory bgContracts = new uint8[](1);
        bgContracts[0] = 1;

        uint256[] memory durations = new uint256[](1);
        durations[0] = 3;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);
        stakingContract.deposit(tokenIds, bgContracts);

        // nope
        stakingContract.depositAndLock(tokenIds, durations, bgContracts);

        cheats.stopPrank();
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

    function testCalculateRewardsLocked() public {
        // deposit and lock some jpegs
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = kidsIds[2];
        tokenIds[1] = pupsIds[1];
        tokenIds[2] = pupsIds[2];

        uint8[] memory bgContracts = new uint8[](3);
        bgContracts[0] = 0;
        bgContracts[1] = 1;
        bgContracts[2] = 1;

        uint256[] memory durations = new uint256[](3);
        durations[0] = 1;
        durations[1] = 2;
        durations[2] = 3;

        cheats.prank(USER_ADDRESS);
        stakingContract.depositAndLock(tokenIds, durations, bgContracts);

        // roll forward "two weeks"
        cheats.roll(block.number + 7200 * 14);

        uint256[] memory rewards = stakingContract.calculateRewards(
            USER_ADDRESS,
            tokenIds,
            bgContracts
        );

        assertEq(rewards[0], 154 * 10**17);
        assertEq(rewards[1], 175 * 10**17);
        assertEq(rewards[2], 196 * 10**17);
    }

    function testClaimRewards() public {
        // deposit and lock some jpegs
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = kidsIds[2];
        tokenIds[1] = pupsIds[1];
        tokenIds[2] = pupsIds[2];

        uint8[] memory bgContracts = new uint8[](3);
        bgContracts[0] = 0;
        bgContracts[1] = 1;
        bgContracts[2] = 1;

        uint256[] memory durations = new uint256[](3);
        durations[0] = 1;
        durations[1] = 2;
        durations[2] = 3;

        cheats.prank(USER_ADDRESS);
        stakingContract.depositAndLock(tokenIds, durations, bgContracts);

        // roll forward "two weeks"
        cheats.roll(block.number + 7200 * 14);

        cheats.prank(USER_ADDRESS);
        stakingContract.claimRewards();

        uint256 gumBalance = gumContract.balanceOf(USER_ADDRESS);
        assertEq(gumBalance, (154 + 175 + 196) * (10**17));
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

    // make sure that after a jpeg is relocked, lock block
    // is updated
    function testReadLockBlocks() public {
        // deposit and lock a jpeg
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = kidsIds[8];

        uint8[] memory bgContracts = new uint8[](1);
        bgContracts[0] = 0;

        uint256[] memory durations = new uint256[](1);
        durations[0] = 1;

        cheats.prank(USER_ADDRESS);
        stakingContract.depositAndLock(tokenIds, durations, bgContracts);

        uint256 oldBlockNumber = block.number;
        uint256 newBlockNumber = oldBlockNumber + 7200 * 31;

        uint256 lockBlockOne = stakingContract.lockBlocks(
            Staking.BGContract(bgContracts[0]),
            tokenIds[0]
        );

        assertEq(lockBlockOne, oldBlockNumber);

        // roll forward till after lock's expired
        cheats.roll(newBlockNumber);

        // withdraw
        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);
        stakingContract.withdraw(tokenIds, bgContracts);

        // send to another user
        kids.setApprovalForAll(TRANSFER_ADDRESS, true);
        cheats.stopPrank();

        cheats.prank(TRANSFER_ADDRESS);
        kids.safeTransferFrom(USER_ADDRESS, USER_ADDRESS_TWO, tokenIds[0]);

        // next user deposits and locks jpeg
        cheats.prank(USER_ADDRESS_TWO);
        stakingContract.depositAndLock(tokenIds, durations, bgContracts);

        uint256 lockBlockTwo = stakingContract.lockBlocks(
            Staking.BGContract(bgContracts[0]),
            tokenIds[0]
        );

        // ensure that lock block has updated
        assertEq(lockBlockTwo, newBlockNumber);
    }

    // use `lockDurationsByTokenId`, `lockBlocks` and `locksOf`
    // to determine whether a lock has expired
    function testCheckLockExpiration() public {
        // deposit and lock a jpeg
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = pupsIds[4];

        uint8[] memory bgContracts = new uint8[](1);
        bgContracts[0] = 1;

        uint256[] memory durations = new uint256[](1);
        durations[0] = 2;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);
        stakingContract.depositAndLock(tokenIds, durations, bgContracts);

        // roll forward a "week"
        cheats.roll(block.number + 7200 * 7);

        uint256[][2] memory userLocks = stakingContract.locksOf(USER_ADDRESS);
        uint256 lockedTokenId = userLocks[bgContracts[0]][0];
        uint256 lockedTokenDuration = stakingContract.lockDurationsByTokenId(
            Staking.BGContract(bgContracts[0]),
            lockedTokenId
        );
        uint256 lockedTokenDurationInDays = stakingContract.lockDurationsConfig(
            lockedTokenDuration
        );
        uint256 lockedTokenBlock = stakingContract.lockBlocks(
            Staking.BGContract(bgContracts[0]),
            lockedTokenId
        );
        uint256 daysSinceLock = (block.number - lockedTokenBlock) / 7200;
        bool tokenIsExpired = daysSinceLock >= lockedTokenDurationInDays;
        assert(!tokenIsExpired);

        // roll forward past expiration
        cheats.roll(block.number + 7200 * 84);

        uint256 newDaysSinceLock = (block.number - lockedTokenBlock) / 7200;
        bool newTokenIsExpired = newDaysSinceLock >= lockedTokenDurationInDays;
        assert(newTokenIsExpired);

        cheats.stopPrank();
    }

    function testExtendExistingLock() public {
        // deposit and lock a jpeg
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = pupsIds[0];

        uint8[] memory bgContracts = new uint8[](1);
        bgContracts[0] = 1;

        uint256[] memory durations = new uint256[](1);
        durations[0] = 1;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);
        stakingContract.depositAndLock(tokenIds, durations, bgContracts);

        // get initial lock block
        uint256 lockedTokenBlockBefore = stakingContract.lockBlocks(
            Staking.BGContract(bgContracts[0]),
            tokenIds[0]
        );

        // get initial lock duration
        uint256 lockedTokenDurationBefore = stakingContract
            .lockDurationsByTokenId(
                Staking.BGContract(bgContracts[0]),
                tokenIds[0]
            );
        // check it's as expected
        assertEq(durations[0], lockedTokenDurationBefore);

        // check initial user locks
        uint256[][2] memory locksBefore = stakingContract.locksOf(USER_ADDRESS);
        assertEq(locksBefore[bgContracts[0]][0], tokenIds[0]);

        // roll forward a "week"
        cheats.roll(block.number + 7200 * 7);

        // relock for longer duration
        uint256[] memory extendedDurations = new uint256[](1);
        extendedDurations[0] = 2;

        stakingContract.lock(tokenIds, extendedDurations, bgContracts);

        // get updated lock block
        uint256 lockedTokenBlockAfter = stakingContract.lockBlocks(
            Staking.BGContract(bgContracts[0]),
            tokenIds[0]
        );
        // check it's later than initial lock block
        assertLt(lockedTokenBlockBefore, lockedTokenBlockAfter);

        // get updated lock duration
        uint256 lockedTokenDurationAfter = stakingContract
            .lockDurationsByTokenId(
                Staking.BGContract(bgContracts[0]),
                tokenIds[0]
            );
        // check it's as expected
        assertEq(extendedDurations[0], lockedTokenDurationAfter);

        // check updated user locks
        uint256[][2] memory locksAfter = stakingContract.locksOf(USER_ADDRESS);
        assertEq(locksAfter[bgContracts[0]][0], tokenIds[0]);

        cheats.stopPrank();
    }

    // user deposits, waits, locks, waits (lock doesn't expire),
    // claims reward. ensure reward is accurate
    function testComplexScenarioOne() public {
        // deposit a jpeg
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = kidsIds[8];

        uint8[] memory bgContracts = new uint8[](1);
        bgContracts[0] = 0;

        uint256[] memory durations = new uint256[](1);
        durations[0] = 3;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);
        stakingContract.deposit(tokenIds, bgContracts);

        // roll forward "one week"
        cheats.roll(block.number + 7200 * 7);

        // rewards so far: 7 gum

        // lock till the end of days
        stakingContract.lock(tokenIds, durations, bgContracts);

        // roll forward another "week"
        cheats.roll(block.number + 7200 * 7);

        // rewards so far: 7 + 7 * 1.4 => 16.8 gum

        stakingContract.claimRewards();

        uint256 gumBalance = gumContract.balanceOf(USER_ADDRESS);
        assertEq(gumBalance, 168 * (10**17));

        cheats.stopPrank();
    }

    // user deposits, waits, locks, waits (lock expires, then some),
    // claims reward. ensure reward is accurate
    function testComplexScenarioTwo() public {
        // deposit a jpeg
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = kidsIds[8];

        uint8[] memory bgContracts = new uint8[](1);
        bgContracts[0] = 0;

        uint256[] memory durations = new uint256[](1);
        durations[0] = 1;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);
        stakingContract.deposit(tokenIds, bgContracts);

        // roll forward "one week"
        cheats.roll(block.number + 7200 * 7);

        // rewards so far: 7 gum

        // lock for a spell
        stakingContract.lock(tokenIds, durations, bgContracts);

        // roll forward another "two months"
        cheats.roll(block.number + 7200 * 60);

        // rewards so far: 7 + 30 * 1.1 + 30 => 70 gum

        stakingContract.claimRewards();

        uint256 gumBalance = gumContract.balanceOf(USER_ADDRESS);
        assertEq(gumBalance, 70 * (10**18));

        cheats.stopPrank();
    }

    // user deposits and locks, waits (lock doesn't expire),
    // claims reward, waits (lock expires, then some),
    // claims reward. ensure rewards are accurate
    function testComplexScenarioThree() public {
        // deposit and lock a jpeg
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = kidsIds[8];

        uint8[] memory bgContracts = new uint8[](1);
        bgContracts[0] = 0;

        uint256[] memory durations = new uint256[](1);
        durations[0] = 1;

        cheats.startPrank(USER_ADDRESS, USER_ADDRESS);
        stakingContract.depositAndLock(tokenIds, durations, bgContracts);

        // roll forward a "week"
        cheats.roll(block.number + 7200 * 7);

        // rewards so far: 7 * 1.1 => 7.7 gum

        stakingContract.claimRewards();

        // roll forward another "week"
        cheats.roll(block.number + 7200 * 7);

        // rewards so far: 2 * (7 * 1.1) => 15.4 gum

        stakingContract.claimRewards();

        // roll forward another "month"
        cheats.roll(block.number + 7200 * 30);

        // rewards so far: 30 * 1.1 + 14 => 47 gum

        stakingContract.claimRewards();

        uint256 gumBalance = gumContract.balanceOf(USER_ADDRESS);
        assertEq(gumBalance, 47 * (10**18));

        cheats.stopPrank();
    }
}
