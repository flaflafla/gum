// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IGum {
    function mint(address, uint256) external;

    function decimals() external returns (uint8);
}

error NotStarted();
error TokenNotDeposited();
error UnknownBGContract();

/**
 * @notice Accept deposits of Bubblegum Kid and Bubblegum Puppy NFTs
 * ("staking") in exchange for GUM token rewards. Thanks to the Sappy Seals team:
 * this contract is largely based on their staking contract at
 * 0xdf8A88212FF229446e003f8f879e263D3616b57A.
 * @dev Contract defines a "day" as 7200 ethereum blocks.
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

    event GumTokenUpdated(address _gumToken);
    event Started();
    event Stopped();
    event Deposited(address from, uint256[] tokenIds, uint8[] bgContracts);
    event Withdrawn(address to, uint256[] tokenIds, uint8[] bgContracts);
    event StakeRewardRateUpdated(uint256 _stakeRewardRate);
    event RewardClaimed(address to, uint256 amount);

    constructor(address _gumToken) {
        gumToken = _gumToken;
        stakeRewardRate = 1;
        started = false;
    }

    modifier onlyStarted() {
        if (!started) revert NotStarted();
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
        // how many days have elapsed since the NFT was deposited or
        // rewards were claimed?
        uint256 depositDaysElapsed = (block.number - depositBlock) / 7200;
        return stakeRewardRate *
            depositDaysElapsed *
            10**GUM_TOKEN_DECIMALS;
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
     * @dev Claim accrued GUM token rewards for all
     * staked BGK and BGP NFTs -- if caller's rewards are
     * greater than 0, balance will be transferred to
     * caller's address
     */
    function claimRewards() public {
        address account = msg.sender;
        uint256 amount;
        for (uint8 i; i < 2; i++) {
            BGContract bgContract = BGContract(i);
            for (
                uint256 j;
                j < _deposits[account][bgContract].length();
                j = unsafe_inc(j)
            ) {
                uint256 tokenId = _deposits[account][bgContract].at(j);
                uint256 thisAmount = (getRewardsForToken(account, tokenId, i));
                if (thisAmount > 0) {
                    amount += thisAmount;
                    depositBlocks[bgContract][tokenId] = block.number;
                }
            }
        }
        if (amount > 0) {
            _reward(account, amount);
            emit RewardClaimed(account, amount);
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
                revert UnknownBGContract();
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
     * have deposited the NFTs.
     * @param tokenIds The NFTs' ids
     * @param bgContracts The NFTs' contracts -- Kids (0)
     * or Puppies (1) -- with indices corresponding to those
     * of `tokenIds`
     */
    function withdraw(uint256[] calldata tokenIds, uint8[] calldata bgContracts)
        external
    {
        claimRewards();
        address account = msg.sender;
        for (uint256 i; i < tokenIds.length; i = unsafe_inc(i)) {
            uint256 tokenId = tokenIds[i];
            BGContract bgContract = BGContract(bgContracts[i]);
            if (!_deposits[account][bgContract].contains(tokenId)) {
                revert TokenNotDeposited();
            }
            _deposits[account][bgContract].remove(tokenId);
            address nftAddress;
            if (bgContract == BGContract.BGK) {
                nftAddress = BGK;
            } else if (bgContract == BGContract.BGP) {
                nftAddress = BGP;
            } else {
                revert UnknownBGContract();
            }
            IERC721(nftAddress).safeTransferFrom(
                address(this),
                account,
                tokenId,
                ""
            );
        }
        emit Withdrawn(account, tokenIds, bgContracts);
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
}
