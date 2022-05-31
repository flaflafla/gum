// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./test/console.sol";

interface IGum {
    function mint(address, uint256) external;

    function decimals() external returns (uint8);
}

/**
 * @notice Accept deposits of Bubblegum Kid and Bubblegum Puppy NFTs
 * ("staking") in exchange for GUM token rewards. Staked NFTs can
 * also be "locked," preventing their withdrawal for a period of time
 * in exchange for accelerated rewards. Thanks to the Sappy Seals team:
 * this contract is largely based on their staking contract at
 * 0xdf8A88212FF229446e003f8f879e263D3616b57A.
 * @dev Contract defines a "day" as 6000 ethereum blocks.
 */
contract Staking is ERC721Holder, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    address public constant BGK = 0xa5ae87B40076745895BB7387011ca8DE5fde37E0;
    address public constant BGP = 0x86e9C5ad3D4b5519DA2D2C19F5c71bAa5Ef40933;
    enum BGContract {
        BGK,
        BGP
    }

    uint256 public constant GUM_TOKEN_DECIMALS = 18;

    address public gumToken;

    bool public started;

    mapping(address => mapping(BGContract => EnumerableSet.UintSet))
        private _deposits;
    mapping(BGContract => mapping(uint256 => uint256)) public depositBlocks;
    uint256 public stakeRewardRate;

    mapping(address => mapping(BGContract => EnumerableSet.UintSet))
        private _locks;
    mapping(BGContract => mapping(uint256 => uint256)) public lockBlocks;
    mapping(BGContract => mapping(uint256 => uint256))
        public lockDurationsByTokenId;
    // in "days" (multiples of 6000 blocks)
    uint256[4] public lockDurationsConfig;
    // decimals == 3
    uint256[4] public lockBoostRates;

    event GumTokenUpdated(address _gumToken);
    event Started();
    event Stopped();
    event Deposited(address from, uint256[] tokenIds, uint8[] bgContracts);
    event Withdrawn(address to, uint256[] tokenIds);
    event StakeRewardRateUpdated(uint256 _stakeRewardRate);
    event Locked(
        address from,
        uint256[] tokenIds,
        uint256[] durations,
        uint8[] bgContracts
    );
    event DepositedAndLocked(
        address from,
        uint256[] tokenIds,
        uint256[] durations,
        uint8[] bgContracts
    );
    event LockBoostRatesUpdated(uint256 lockBoostRate, uint256 index);
    event LockDurationsConfigUpdated(uint256 lockDuration, uint256 index);
    event RewardClaimed(address to, uint256 amount);

    constructor(address _gumToken) {
        gumToken = _gumToken;
        lockBoostRates = [0, 100, 250, 400];
        lockDurationsConfig = [0, 30, 90, 180];
        stakeRewardRate = 1;
        started = false;
    }

    modifier onlyStarted() {
        require(started, "not started");
        _;
    }

    function start() public onlyOwner {
        started = true;
        emit Started();
    }

    function stop() public onlyOwner {
        started = false;
        emit Stopped();
    }

    function unsafe_inc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

    /**
     * @dev Change the address of the reward token contract (must
     * support ERC20 functions named in IGum interface and conform
     * to hardcoded GUM_TOKEN_DECIMALS constant).
     */
    function updateGumToken(address _gumToken) public onlyOwner {
        gumToken = _gumToken;
        emit GumTokenUpdated(_gumToken);
    }

    function updateLockBoostRates(uint256 lockBoostRate, uint256 index)
        public
        onlyOwner
    {
        lockBoostRates[index] = lockBoostRate;
        emit LockBoostRatesUpdated(lockBoostRate, index);
    }

    function updateLockDurationsConfig(uint256 lockDuration, uint256 index)
        public
        onlyOwner
    {
        lockDurationsConfig[index] = lockDuration;
        emit LockDurationsConfigUpdated(lockDuration, index);
    }

    function updateStakeRewardRate(uint256 _stakeRewardRate) public onlyOwner {
        stakeRewardRate = _stakeRewardRate;
        emit StakeRewardRateUpdated(_stakeRewardRate);
    }

    /**
     * @dev Mint GUM token rewards
     * @param to The recipient's ethereum address
     * @param amount The amount to mint
     */
    function _reward(address to, uint256 amount) internal {
        IGum(gumToken).mint(to, amount);
    }

    /**
     * @dev Calculate accrued GUM token rewards for a given
     * BGK or BGP NFT
     * @param account The user's ethereum address
     * @param tokenId The NFT's id
     * @param _bgContract Kids (0) or Puppies (1)
     * @return rewards
     */
    function getRewardsForToken(
        address account,
        uint256 tokenId,
        uint8 _bgContract
    ) internal view returns (uint256) {
        BGContract bgContract = BGContract(_bgContract);
        // the user has not staked this nft
        if (!_deposits[account][bgContract].contains(tokenId)) {
            return 0;
        }
        // when was the NFT deposited?
        uint256 depositBlock = depositBlocks[bgContract][tokenId];
        // separately calculate `boostedRewards` (for locked NFTs) and
        // `regularRewards` (for NFTs that have been staked but not
        // locked -- see below). add them together to find total rewards
        uint256 boostedRewards;
        // is (or was) the NFT locked?
        if (_locks[account][bgContract].contains(tokenId)) {
            // when was the NFT locked?
            uint256 lockBlock = lockBlocks[bgContract][tokenId];
            // `durationIndex` is used to access values on `lockDurationsConfig`
            // and `lockBoostRates`
            uint256 durationIndex = lockDurationsByTokenId[bgContract][tokenId];
            // how many days was the NFT locked for?
            uint256 durationDays = lockDurationsConfig[durationIndex];
            // `startingBlock` is the block when token rewards began accruing.
            // this could be the block at which the token was locked,
            // or it could be the block at which the user last claimed
            // rewards (which is tracked by updates to `depositBlocks`
            // -- see `claimRewards`)
            uint256 startingBlock = lockBlock;
            if (startingBlock < depositBlock) {
                startingBlock = depositBlock;
            }
            // `endingBlock` is when rewards stop accruing. this is either the
            // block at which the lock expired, if it has expired, or the
            // current block, if it hasn't
            uint256 endingBlock = lockBlock + durationDays * 6000;
            if (endingBlock > block.number) {
                endingBlock = block.number;
            }
            // how many days have passed from initial lock or last claim
            // to the ending block?
            uint256 lockDaysElapsed = (endingBlock - startingBlock) / 6000;
            uint256 boost = lockBoostRates[durationIndex];
            // if the user has claimed since locking, account for that
            // by calculating `remainingDurationDays`
            uint256 remainingDurationDays = durationDays -
                (depositBlock - lockBlock) /
                6000;
            // if the remaining lock time hasn't elapsed, reward based on
            // elapsed days, otherwise reward based on `remainingDurationDays`.
            // in other worrds, cap rewards at the remaining lock time,
            // even if more time has elapsed since lock or last claim
            if (lockDaysElapsed < remainingDurationDays) {
                boostedRewards = lockDaysElapsed * boost;
            } else {
                boostedRewards = remainingDurationDays * boost;
            }
            // calculate boosted rewards
            boostedRewards = (boostedRewards * 10**GUM_TOKEN_DECIMALS) / 1000;
        }
        // how many days have elapsed since the NFT was deposited or
        // rewards were claimed?
        uint256 depositDaysElapsed = (block.number - depositBlock) / 6000;
        // calculate regular deposit rewards
        uint256 regularRewards = stakeRewardRate *
            depositDaysElapsed *
            10**GUM_TOKEN_DECIMALS;
        return regularRewards + boostedRewards;
    }

    /**
     * @dev Calculate accrued GUM token rewards for a set
     * of BGK and BGP NFTs
     * @param account The user's ethereum address
     * @param tokenIds The NFTs' ids
     * @param bgContracts The NFTs' contracts -- Kids (0)
     * or Puppies (1) -- with indices corresponding to those
     * of `tokenIds`
     * @return rewards
     */
    function calculateRewards(
        address account,
        uint256[] calldata tokenIds,
        uint8[] calldata bgContracts
    ) public view returns (uint256[] memory rewards) {
        rewards = new uint256[](tokenIds.length);
        for (uint256 i; i < tokenIds.length; i = unsafe_inc(i)) {
            rewards[i] = getRewardsForToken(
                account,
                tokenIds[i],
                bgContracts[i]
            );
        }
    }

    /**
     * @dev Claim accrued GUM token rewards for a set
     * of BGK and BGP NFTs -- if caller's rewards are
     * greater than 0, balance will be transferred to
     * caller's address
     * @param tokenIds The NFTs' ids
     * @param bgContracts The NFTs' contracts -- Kids (0)
     * or Puppies (1) -- with indices corresponding to those
     * of `tokenIds`
     */
    function claimRewards(
        uint256[] calldata tokenIds,
        uint8[] calldata bgContracts
    ) public {
        uint256 amount;
        address to = msg.sender;
        uint256[] memory rewards = calculateRewards(to, tokenIds, bgContracts);
        for (uint256 i; i < tokenIds.length; i = unsafe_inc(i)) {
            BGContract bgContract = BGContract(bgContracts[i]);
            amount += rewards[i];
            depositBlocks[bgContract][tokenIds[i]] = block.number;
        }
        if (amount > 0) {
            _reward(to, amount);
            emit RewardClaimed(to, amount);
        }
    }

    /**
     * @dev Deposit ("stake") a set of BGK and BGP NFTs. Caller
     * must be the owner of the NFTs supplied as arguments.
     * @param tokenIds The NFTs' ids
     * @param bgContracts The NFTs' contracts -- Kids (0)
     * or Puppies (1) -- with indices corresponding to those
     * of `tokenIds`
     */
    function deposit(uint256[] calldata tokenIds, uint8[] calldata bgContracts)
        external
        onlyStarted
    {
        address account = msg.sender;
        for (uint256 i; i < tokenIds.length; i = unsafe_inc(i)) {
            uint256 tokenId = tokenIds[i];
            BGContract bgContract = BGContract(bgContracts[i]);
            address bgContractAddress;
            if (bgContract == BGContract.BGK) {
                bgContractAddress = BGK;
            } else if (bgContract == BGContract.BGP) {
                bgContractAddress = BGP;
            } else {
                revert("unknown contract address");
            }
            IERC721(bgContractAddress).safeTransferFrom(
                account,
                address(this),
                tokenId,
                ""
            );
            _deposits[account][bgContract].add(tokenId);
            depositBlocks[bgContract][tokenId] = block.number;
        }
        emit Deposited(account, tokenIds, bgContracts);
    }

    /**
     * @dev Withdraw ("unstake") a set of deposited BGK and BGP
     * NFTs. Calling `withdraw` automatically claims accrued
     * rewards on the NFTs supplied as arguments. Caller must
     * have deposited the NFTs, and they must not be subject
     * to unexpired locks.
     * @param tokenIds The NFTs' ids
     * @param bgContracts The NFTs' contracts -- Kids (0)
     * or Puppies (1) -- with indices corresponding to those
     * of `tokenIds`
     */
    function withdraw(uint256[] calldata tokenIds, uint8[] calldata bgContracts)
        external
    {
        claimRewards(tokenIds, bgContracts);
        address account = msg.sender;
        for (uint256 i; i < tokenIds.length; i = unsafe_inc(i)) {
            uint256 tokenId = tokenIds[i];
            BGContract bgContract = BGContract(bgContracts[i]);
            require(
                _deposits[account][bgContract].contains(tokenId),
                "token not deposited"
            );
            // if the token has an unexpired lock, don't allow
            // withdrawal
            if (_locks[account][bgContract].contains(tokenId)) {
                uint256 duration = lockDurationsConfig[
                    lockDurationsByTokenId[bgContract][tokenId]
                ];
                uint256 daysElapsed = (block.number -
                    lockBlocks[bgContract][tokenId]) / 6000;
                require(daysElapsed >= duration, "token still locked");
            }
            _deposits[account][bgContract].remove(tokenId);
            lockDurationsByTokenId[bgContract][tokenId] = 0;
            _locks[account][bgContract].remove(tokenId);
            address nftAddress;
            if (bgContract == BGContract.BGK) {
                nftAddress = BGK;
            } else if (bgContract == BGContract.BGP) {
                nftAddress = BGP;
            } else {
                revert("unknown contract address");
            }
            IERC721(nftAddress).safeTransferFrom(
                address(this),
                account,
                tokenId,
                ""
            );
        }
    }

    /**
     * @dev Get the ids of Kid and Puppy NFTs staked by the
     * user supplied in the `account` argument
     * @param account The depositor's ethereum address
     * @return bgContracts The ids of the deposited NFTs,
     * as an array: the first item is an array of Kid ids,
     * the second an array of Pup ids
     */
    function depositsOf(address account)
        external
        view
        returns (uint256[][2] memory)
    {
        EnumerableSet.UintSet storage bgkDepositSet = _deposits[account][
            BGContract.BGK
        ];
        uint256[] memory bgkIds = new uint256[](bgkDepositSet.length());
        for (uint256 i; i < bgkDepositSet.length(); i = unsafe_inc(i)) {
            bgkIds[i] = bgkDepositSet.at(i);
        }
        EnumerableSet.UintSet storage bgpDepositSet = _deposits[account][
            BGContract.BGP
        ];
        uint256[] memory bgpIds = new uint256[](bgpDepositSet.length());
        for (uint256 i; i < bgpDepositSet.length(); i = unsafe_inc(i)) {
            bgpIds[i] = bgpDepositSet.at(i);
        }
        return [bgkIds, bgpIds];
    }

    /**
     * @dev Lock a set of deposited BGK and BGP NFTs. This
     * will prevent them from being withdrawn for the
     * periods of time supplied (indirectly) via the `durations`
     * argument, in exchange for accelerated rewards (see
     * `lockBoostRates`). Caller must have deposited the NFTs.
     * @param tokenIds The NFTs' ids
     * @param durations The durations for which the NFTs should
     * be locked, with indices corresponding to those of
     * `tokenIds`. Each "duration" represents an index that will
     * be used to access values on `lockDurationsConfig` and
     * `lockBoostRates`
     * @param bgContracts The NFTs' contracts -- Kids (0)
     * or Puppies (1) -- with indices corresponding to those
     * of `tokenIds`
     */
    function lock(
        uint256[] calldata tokenIds,
        uint256[] calldata durations,
        uint8[] calldata bgContracts
    ) external onlyStarted {
        claimRewards(tokenIds, bgContracts);
        address account = msg.sender;
        for (uint256 i; i < tokenIds.length; i = unsafe_inc(i)) {
            uint256 tokenId = tokenIds[i];
            BGContract bgContract = BGContract(bgContracts[i]);
            require(
                _deposits[account][bgContract].contains(tokenId),
                "token not deposited"
            );
            _locks[account][bgContract].add(tokenId);
            lockDurationsByTokenId[bgContract][tokenId] = durations[i];
            lockBlocks[bgContract][tokenId] = block.number;
        }
        emit Locked(account, tokenIds, durations, bgContracts);
    }

    /**
     * @dev Get the ids of Kid and Puppy NFTs locked by the
     * user supplied in the `account` argument, whether the
     * locks are expired or not. Use `lockDurationsByTokenId`
     * to determine whether a lock has expired.
     * @param account The depositor's ethereum address
     * @return bgContracts The ids of the locked NFTs,
     * as an array: the first item is an array of Kid ids,
     * the second an array of Pup ids
     */
    function locksOf(address account)
        external
        view
        returns (uint256[][2] memory)
    {
        EnumerableSet.UintSet storage bgkLockSet = _locks[account][
            BGContract.BGK
        ];
        uint256[] memory bgkIds = new uint256[](bgkLockSet.length());
        for (uint256 i; i < bgkLockSet.length(); i = unsafe_inc(i)) {
            bgkIds[i] = bgkLockSet.at(i);
        }
        EnumerableSet.UintSet storage bgpLockSet = _locks[account][
            BGContract.BGP
        ];
        uint256[] memory bgpIds = new uint256[](bgpLockSet.length());
        for (uint256 i; i < bgpLockSet.length(); i = unsafe_inc(i)) {
            bgpIds[i] = bgpLockSet.at(i);
        }
        return [bgkIds, bgpIds];
    }

    /**
     * @dev Combine the `deposit` and `lock` functions to save
     * users a transaction. Note that this function doesn't
     * claim rewards like `lock` does, since the NFTs aren't
     * already staked. (If they are, function will error.)
     * @param tokenIds The NFTs' ids
     * @param durations The durations for which the NFTs should
     * be locked, with indices corresponding to those of
     * `tokenIds`. Each "duration" represents an index that will
     * be used to access values on `lockDurationsConfig` and
     * `lockBoostRates`
     * @param bgContracts The NFTs' contracts -- Kids (0)
     * or Puppies (1) -- with indices corresponding to those
     * of `tokenIds`
     */
    function depositAndLock(
        uint256[] calldata tokenIds,
        uint256[] calldata durations,
        uint8[] calldata bgContracts
    ) external onlyStarted {
        address account = msg.sender;
        for (uint256 i; i < tokenIds.length; i = unsafe_inc(i)) {
            uint256 tokenId = tokenIds[i];
            BGContract bgContract = BGContract(bgContracts[i]);
            _deposits[account][bgContract].add(tokenId);
            depositBlocks[bgContract][tokenId] = block.number;
            _locks[account][bgContract].add(tokenId);
            lockDurationsByTokenId[bgContract][tokenId] = durations[i];
            lockBlocks[bgContract][tokenId] = block.number;
            address nftAddress;
            if (bgContract == BGContract.BGK) {
                nftAddress = BGK;
            } else if (bgContract == BGContract.BGP) {
                nftAddress = BGP;
            } else {
                revert("unknown contract address");
            }
            IERC721(nftAddress).safeTransferFrom(
                account,
                address(this),
                tokenId,
                ""
            );
        }
        emit DepositedAndLocked(account, tokenIds, durations, bgContracts);
    }
}
