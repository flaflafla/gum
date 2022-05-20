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

// note: this contract assumes 6000 ethereum blocks per day
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

    // duration is the index of lockBoostRates/lockDurationsConfig
    mapping(BGContract => mapping(uint256 => uint256))
        public lockDurationsByTokenId;
    uint256[5] public lockDurationsConfig; // in days
    uint256[5] public lockBoostRates; // decimals == 3

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
        lockBoostRates = [1000, 1100, 1250, 1400];
        lockDurationsConfig = [0, 30, 90, 180];
        stakeRewardRate = 1;
        started = false;
    }

    function start() public onlyOwner {
        started = true;
        emit Started();
    }

    function stop() public onlyOwner {
        started = false;
        emit Stopped();
    }

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

    function getRate(
        address account,
        uint256 tokenId,
        uint8 _bgContract
    ) internal returns (uint256) {
        uint256 boost = 1000;
        BGContract bgContract = BGContract(_bgContract);
        if (_locks[account][bgContract].contains(tokenId)) {
            uint256 duration = lockDurationsConfig[
                lockDurationsByTokenId[bgContract][tokenId]
            ];
            uint256 lockDaysElapsed = (block.number -
                lockBlocks[bgContract][tokenId]) / 6000;
            if (lockDaysElapsed <= duration) {
                boost = lockBoostRates[duration];
            }
        }
        uint256 depositDaysElapsed = (block.number -
            depositBlocks[bgContract][tokenId]) / 6000;
        return
            ((stakeRewardRate *
                depositDaysElapsed *
                10**uint256(IGum(gumToken).decimals())) * boost) / 1000;
    }

    function calculateRewards(
        address account,
        uint256[] memory tokenIds,
        uint8[] calldata bgContracts
    ) public returns (uint256[] memory rewards) {
        rewards = new uint256[](tokenIds.length);
        for (uint256 i; i < tokenIds.length; i++) {
            uint256 rate = getRate(account, tokenIds[i], bgContracts[i]);
            rewards[i] =
                rate *
                (
                    _deposits[account][BGContract(bgContracts[i])].contains(
                        tokenIds[i]
                    )
                        ? 1
                        : 0
                );
        }
    }

    function claimRewards(
        uint256[] calldata tokenIds,
        uint8[] calldata bgContracts
    ) public {
        require(
            tokenIds.length == bgContracts.length,
            "argument lengths don't match"
        );
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
    {
        require(started, "not started");
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
                require(daysElapsed > duration, "token still locked");
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
    ) external {
        require(started, "not started");
        require(
            tokenIds.length == durations.length &&
                tokenIds.length == bgContracts.length,
            "token ids don't match durations"
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
    ) external {
        require(started, "not started");
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
