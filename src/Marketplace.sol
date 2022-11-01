// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@chainlink/v0.8/ConfirmedOwner.sol";
import "@chainlink/v0.8/VRFV2WrapperConsumerBase.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

uint32 constant CALLBACK_GAS_LIMIT = 100000;
uint16 constant RANDOMNESS_REQUEST_CONFIRMATIONS = 3;
uint32 constant NUM_RANDOM_WORDS = 2;
address constant GOERLI_LINK_ADDRESS = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
address constant GOERLI_WRAPPER_ADDRESS = 0x708701a1DfF4f478de54383E49a627eD4852C816;

error InsufficientFunds();
error InsufficientSupply();
error InvalidQuantity();
error UnknownTokenStandard();
error ZeroListingPrice();
error ZeroPurchasePrice();
error ZeroQuantity();
error ZeroTokenContract();

// TODO: make it not broken
contract Marketplace is
    ConfirmedOwner,
    ERC1155Holder,
    ERC721Holder,
    Ownable,
    VRFV2WrapperConsumerBase
{
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

    struct RandomnessRequestStatus {
        uint256 paid;
        bool fulfilled;
        uint256[] randomWords;
    }

    address public gumToken;
    uint256 nextRaffleId = 0;
    // standard (ERC1155 or ERC721) => contract address => token id => price
    mapping(TokenStandard => mapping(address => mapping(uint256 => uint256)))
        private _prices;
    mapping(uint256 => Raffle) private _raffles;
    mapping(uint256 => RandomnessRequestStatus)
        public randomnessRequestStatuses;

    uint256[] public randomnessRequestIds;
    uint256 public lastRandomnessRequestId;

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
    event RandomnessRequestSent(uint256 requestId, uint32 numWords);
    event RandomnessRequestFulfilled(
        uint256 requestId,
        uint256[] randomWords,
        uint256 payment
    );

    constructor(address _gumToken)
        ConfirmedOwner(msg.sender)
        VRFV2WrapperConsumerBase(GOERLI_LINK_ADDRESS, GOERLI_WRAPPER_ADDRESS)
    {
        gumToken = _gumToken;
    }

    function requestRandomWords()
        external
        onlyOwner
        returns (uint256 requestId)
    {
        requestId = requestRandomness(
            CALLBACK_GAS_LIMIT,
            RANDOMNESS_REQUEST_CONFIRMATIONS,
            NUM_RANDOM_WORDS
        );
        randomnessRequestStatuses[requestId] = RandomnessRequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(CALLBACK_GAS_LIMIT),
            randomWords: new uint256[](0),
            fulfilled: false
        });
        randomnessRequestIds.push(requestId);
        lastRandomnessRequestId = requestId;
        emit RandomnessRequestSent(requestId, NUM_RANDOM_WORDS);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(
            randomnessRequestStatuses[_requestId].paid > 0,
            "request not found"
        );
        randomnessRequestStatuses[_requestId].fulfilled = true;
        randomnessRequestStatuses[_requestId].randomWords = _randomWords;
        emit RandomnessRequestFulfilled(
            _requestId,
            _randomWords,
            randomnessRequestStatuses[_requestId].paid
        );
    }

    function getRequestStatus(uint256 _requestId)
        external
        view
        returns (
            uint256 paid,
            bool fulfilled,
            uint256[] memory randomWords
        )
    {
        require(
            randomnessRequestStatuses[_requestId].paid > 0,
            "request not found"
        );
        RandomnessRequestStatus memory request = randomnessRequestStatuses[_requestId];
        return (request.paid, request.fulfilled, request.randomWords);
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
        return _prices[tokenStandard][_tokenContract][tokenId];
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
