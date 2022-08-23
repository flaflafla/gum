// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

error InsufficientFunds();
error InsufficientSupply();
error InvalidQuantity();
error UnknownTokenStandard();
error ZeroListingPrice();
error ZeroPurchasePrice();
error ZeroQuantity();
error ZeroTokenContract();

contract Marketplace is ERC1155Holder, ERC721Holder, Ownable {
    enum PrizeType {
        META, // nft prize
        IRL // physical merch or other offchain prize
    }

    enum TokenStandard {
        ERC1155,
        ERC721
    }

    struct MetaPrize {
        TokenStandard tokenStandard;
        address _tokenContract;
        uint256 tokenId;
    }

    struct Raffle {
        uint256 gumTicketPrice;
        uint256 startBlock;
        uint256 endBlock;
        MetaPrize metaPrize;
        string irlPrize;
        PrizeType prizeType;
    }

    address public gumToken;
    uint256 nextRaffleId = 0;
    // standard (ERC1155 or ERC721) => contract address => token id => price
    mapping(TokenStandard => mapping(address => mapping(uint256 => uint256)))
        private _prices;
    mapping(uint256 => Raffle) private _raffles;

    event GumTokenUpdated(address _gumToken);
    event ItemListed(
        uint8 _tokenStandard,
        address _tokenContract,
        uint256 tokenId,
        uint256 priceInGumInteger
    );
    event ItemSold(
        uint8 _tokenStandard,
        address _tokenContract,
        uint256 tokenId,
        uint256 quantity,
        address buyer,
        uint256 price // total paid for all items, not price per item
    );
    event RaffleCreated(Raffle raffle);

    constructor(address _gumToken) {
        gumToken = _gumToken;
    }

    function updateGumToken(address _gumToken) public onlyOwner {
        gumToken = _gumToken;
        emit GumTokenUpdated(_gumToken);
    }

    function listItem(
        uint8 _tokenStandard,
        address _tokenContract,
        uint256 tokenId,
        uint256 priceInGumInteger
    ) public onlyOwner {
        if (_tokenStandard > 1) revert UnknownTokenStandard();
        if (_tokenContract == address(0)) revert ZeroTokenContract();
        if (priceInGumInteger < 1) revert ZeroListingPrice();
        TokenStandard tokenStandard = TokenStandard(_tokenStandard);
        _prices[tokenStandard][_tokenContract][tokenId] =
            priceInGumInteger *
            10**18;
        emit ItemListed(
            _tokenStandard,
            _tokenContract,
            tokenId,
            priceInGumInteger
        );
    }

    function handleERC1155Sale(
        address _tokenContract,
        uint256 tokenId,
        uint256 quantity,
        address buyer
    ) internal {
        IERC1155 tokenContract = IERC1155(_tokenContract);
        uint256 supply = tokenContract.balanceOf(address(this), tokenId);
        if (supply < quantity) revert InsufficientSupply();
        tokenContract.safeTransferFrom(
            address(this),
            buyer,
            tokenId,
            quantity,
            "0x0"
        );
    }

    function handleERC721Sale(
        address _tokenContract,
        uint256 tokenId,
        address buyer
    ) internal {
        IERC721 tokenContract = IERC721(_tokenContract);
        tokenContract.safeTransferFrom(address(this), buyer, tokenId);
    }

    function getItemPrice(
        uint8 _tokenStandard,
        address _tokenContract,
        uint256 tokenId
    ) public view returns (uint256) {
        if (_tokenStandard > 1) revert UnknownTokenStandard();
        if (_tokenContract == address(0)) revert ZeroTokenContract();
        TokenStandard tokenStandard = TokenStandard(_tokenStandard);
        return _prices[tokenStandard][_tokenContract][tokenId] * 10**18;
    }

    function purchaseItem(
        uint8 _tokenStandard,
        address _tokenContract,
        uint256 tokenId,
        uint256 quantity
    ) public {
        if (quantity == 0) revert ZeroQuantity();
        uint256 price = getItemPrice(_tokenStandard, _tokenContract, tokenId) *
            quantity;
        if (price == 0) revert ZeroPurchasePrice();
        if (_tokenStandard == 0) {
            handleERC1155Sale(_tokenContract, tokenId, quantity, msg.sender);
        } else {
            if (quantity != 1) revert InvalidQuantity();
            handleERC721Sale(_tokenContract, tokenId, msg.sender);
        }
        IERC20 gumContract = IERC20(gumToken);
        uint256 gumBalance = gumContract.balanceOf(msg.sender);
        if (gumBalance < price) revert InsufficientFunds();
        gumContract.transferFrom(msg.sender, address(this), price);
        emit ItemSold(
            _tokenStandard,
            _tokenContract,
            tokenId,
            quantity,
            msg.sender,
            price
        );
    }

    function deleteMarketListing(
        uint8 _tokenStandard,
        address _tokenContract,
        uint256 tokenId
    ) public onlyOwner {
        if (_tokenStandard > 1) revert UnknownTokenStandard();
        if (_tokenContract == address(0)) revert ZeroTokenContract();
        TokenStandard tokenStandard = TokenStandard(_tokenStandard);
        delete _prices[tokenStandard][_tokenContract][tokenId];
    }

    //   function createRaffle() public onlyOwner {}

    //   function claimRafflePrize() public {}

    //   function getRaffleInfo(uint256 id) public {}

    function withdrawItems(
        uint8 _tokenStandard,
        address _tokenContract,
        uint256 tokenId,
        uint256 quantity
    ) public onlyOwner {
        if (quantity == 0) revert ZeroQuantity();
        if (_tokenStandard > 1) revert UnknownTokenStandard();
        if (_tokenContract == address(0)) revert ZeroTokenContract();
        if (_tokenStandard == 0) {
            IERC1155 tokenContract = IERC1155(_tokenContract);
            uint256 supply = tokenContract.balanceOf(address(this), tokenId);
            if (supply < quantity) revert InsufficientSupply();
            tokenContract.safeTransferFrom(
                address(this),
                msg.sender,
                tokenId,
                quantity,
                "0x0"
            );
        } else {
            if (quantity != 1) revert InvalidQuantity();
            IERC721 tokenContract = IERC721(_tokenContract);
            tokenContract.safeTransferFrom(address(this), msg.sender, tokenId);
        }
    }

    function withdrawERC20(address _tokenContract, uint256 amount)
        public
        onlyOwner
    {
        if (_tokenContract == address(0)) revert ZeroTokenContract();
        IERC20 tokenContact = IERC20(_tokenContract);
        uint256 balance = tokenContact.balanceOf(address(this));
        if (balance < amount) revert InsufficientFunds();
        tokenContact.transfer(msg.sender, amount);
    }
}
