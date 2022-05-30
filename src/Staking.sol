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
 * @notice Accept deposits of BubblegumKid and BubblegumPuppy NFTs
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

    /**
     * @dev Change the address of the reward token contract (must
     * support ERC20 functions named in IGum interface).
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

    function _reward(address to, uint256 amount) internal {
        IGum(gumToken).mint(to, amount);
    }

    /**
     * @dev Calculate accrued GUM token rewards for a given
     * BGK or BGP NFT
     * @param account The user's ethereum address
     * @param tokenId The NFT's id
     * @param _bgContract Kids (0) or Puppies (1)
     * @return Rewards
     */
    function getRewardsForToken(
        address account,
        uint256 tokenId,
        uint8 _bgContract
    ) internal returns (uint256) {
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
        uint256 boostedRewards = 0;
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
            } else {
                // if the lock has expired, remove the NFT from `lockBlocks`
                // to save gas on next claim
                _locks[account][bgContract].remove(tokenId);
            }
            // how many days have passed from initial lock or last claim
            // to the ending block?
            uint256 lockDaysElapsed = (endingBlock - startingBlock) / 6000;
            uint256 boost = lockBoostRates[durationIndex];
            // if the user has claimed since locking, account for that
            // by calculating `remainingDurationDays`
            uint256 remainingDurationDays = durationDays -
                (depositBlock - lockBlock) *
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
            boostedRewards =
                (boostedRewards * 10**uint256(IGum(gumToken).decimals())) /
                1000;
        }
        // how many days have elapsed since the NFT was deposited or
        // rewards were claimed?
        uint256 depositDaysElapsed = (block.number - depositBlock) / 6000;
        // calculate regular deposit rewards
        uint256 regularRewards = stakeRewardRate *
            depositDaysElapsed *
            10**uint256(IGum(gumToken).decimals());
        return regularRewards + boostedRewards;
    }

    function calculateRewards(
        address account,
        uint256[] calldata tokenIds,
        uint8[] calldata bgContracts
    ) public returns (uint256[] memory rewards) {
        require(
            tokenIds.length == bgContracts.length,
            "argument lengths don't match"
        );
        rewards = new uint256[](tokenIds.length);
        for (uint256 i; i < tokenIds.length; i++) {
            rewards[i] = getRewardsForToken(
                account,
                tokenIds[i],
                bgContracts[i]
            );
        }
    }

    function claimRewards(
        uint256[] calldata tokenIds,
        uint8[] calldata bgContracts
    ) public {
        uint256 amount;
        address to = msg.sender;
        uint256[] memory rewards = calculateRewards(to, tokenIds, bgContracts);
        for (uint256 i; i < tokenIds.length; i++) {
            BGContract bgContract = BGContract(bgContracts[i]);
            amount += rewards[i];
            depositBlocks[bgContract][tokenIds[i]] = block.number;
        }
        if (amount > 0) {
            _reward(to, amount);
            emit RewardClaimed(to, amount);
        }
    }

    function deposit(uint256[] calldata tokenIds, uint8[] calldata bgContracts)
        external
        onlyStarted
    {
        require(
            tokenIds.length == bgContracts.length,
            "argument lengths don't match"
        );
        address account = msg.sender;
        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            BGContract bgContract = BGContract(bgContracts[i]);
            address nftAddress;
            if (bgContract == BGContract.BGK) {
                nftAddress = BGK;
            } else if (bgContract == BGContract.BGP) {
                nftAddress = BGP;
            } else {
                revert("couldn't get nft contract address");
            }
            IERC721(nftAddress).safeTransferFrom(
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

    function withdraw(uint256[] calldata tokenIds, uint8[] calldata bgContracts)
        external
    {
        claimRewards(tokenIds, bgContracts);
        address account = msg.sender;
        require(
            tokenIds.length == bgContracts.length,
            "argument lengths don't match"
        );
        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            BGContract bgContract = BGContract(bgContracts[i]);
            require(
                _deposits[account][bgContract].contains(tokenId),
                "token not deposited"
            );
            if (_locks[account][bgContract].contains(tokenId)) {
                uint256 duration = lockDurationsConfig[
                    lockDurationsByTokenId[bgContract][tokenId]
                ];
                uint256 daysElapsed = (block.number -
                    lockBlocks[bgContract][tokenId]) / 6000;
                require(daysElapsed >= duration, "token still locked");
                // this line can likely be removed, since `claimRewards`
                // removes expired locks
                _locks[account][bgContract].remove(tokenId);
            }
            _deposits[account][bgContract].remove(tokenId);
            lockDurationsByTokenId[bgContract][tokenId] = 0;
            address nftAddress;
            if (bgContract == BGContract.BGK) {
                nftAddress = BGK;
            } else if (bgContract == BGContract.BGP) {
                nftAddress = BGP;
            } else {
                revert("couldn't get nft contract address");
            }
            IERC721(nftAddress).safeTransferFrom(
                address(this),
                account,
                tokenId,
                ""
            );
        }
    }

    function depositsOf(address account)
        external
        view
        returns (uint256[][2] memory)
    {
        EnumerableSet.UintSet storage bgkDepositSet = _deposits[account][
            BGContract.BGK
        ];
        uint256[] memory bgkIds = new uint256[](bgkDepositSet.length());
        for (uint256 i; i < bgkDepositSet.length(); i++) {
            bgkIds[i] = bgkDepositSet.at(i);
        }
        EnumerableSet.UintSet storage bgpDepositSet = _deposits[account][
            BGContract.BGP
        ];
        uint256[] memory bgpIds = new uint256[](bgpDepositSet.length());
        for (uint256 i; i < bgpDepositSet.length(); i++) {
            bgpIds[i] = bgpDepositSet.at(i);
        }
        return [bgkIds, bgpIds];
    }

    function lock(
        uint256[] calldata tokenIds,
        uint256[] calldata durations,
        uint8[] calldata bgContracts
    ) external onlyStarted {
        require(
            tokenIds.length == durations.length &&
                tokenIds.length == bgContracts.length,
            "argument lengths don't match"
        );
        claimRewards(tokenIds, bgContracts);
        address account = msg.sender;
        for (uint256 i; i < tokenIds.length; i++) {
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

    function locksOf(address account)
        external
        view
        returns (uint256[][2] memory)
    {
        EnumerableSet.UintSet storage bgkLockSet = _locks[account][
            BGContract.BGK
        ];
        uint256[] memory bgkIds = new uint256[](bgkLockSet.length());
        for (uint256 i; i < bgkLockSet.length(); i++) {
            bgkIds[i] = bgkLockSet.at(i);
        }
        EnumerableSet.UintSet storage bgpLockSet = _locks[account][
            BGContract.BGP
        ];
        uint256[] memory bgpIds = new uint256[](bgpLockSet.length());
        for (uint256 i; i < bgpLockSet.length(); i++) {
            bgpIds[i] = bgpLockSet.at(i);
        }
        return [bgkIds, bgpIds];
    }

    function depositAndLock(
        uint256[] calldata tokenIds,
        uint256[] calldata durations,
        uint8[] calldata bgContracts
    ) external onlyStarted {
        require(
            tokenIds.length == durations.length &&
                tokenIds.length == bgContracts.length,
            "argument lengths don't match"
        );
        address account = msg.sender;
        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            BGContract bgContract = BGContract(bgContracts[i]);
            require(
                !_locks[account][bgContract].contains(tokenId),
                "token already locked"
            );
            require(
                !_deposits[account][bgContract].contains(tokenId),
                "token already deposited"
            );
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
                revert("couldn't get nft contract address");
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
