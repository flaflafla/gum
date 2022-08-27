// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../Gum.sol";
import "../Marketplace.sol";
import "./DummyERC721.sol";
import "./DummyERC1155.sol";

interface CheatCodes {
    function prank(address) external;

    function startPrank(address, address) external;

    function stopPrank() external;
}

contract MarketplaceTest is DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);
    Gum gumContract;
    Marketplace marketplaceContract;
    DummyERC721 dummyERC721One;
    DummyERC721 dummyERC721Two;
    DummyERC1155 dummyERC1155One;
    DummyERC1155 dummyERC1155Two;

    address USER_ADDRESS = address(1);
    address SPENDER_ADDRESS = address(2);
    address RANDO_ADDRESS = address(3);
    address OWNER_ADDRESS = address(4);
    address STAKING_ADDRESS = address(5);

    function setUp() public {
        gumContract = new Gum(STAKING_ADDRESS);
        gumContract.mint(USER_ADDRESS, 1_000_000);
        gumContract.updateTransferAllowList(address(marketplaceContract), 0);
        marketplaceContract = new Marketplace(address(gumContract));
        gumContract.transferOwnership(OWNER_ADDRESS);
        marketplaceContract.transferOwnership(OWNER_ADDRESS);
        dummyERC721One = new DummyERC721();
        dummyERC721One.mint(USER_ADDRESS, 10);
        dummyERC721One.mint(OWNER_ADDRESS, 10);
        dummyERC721Two = new DummyERC721();
        dummyERC721Two.mint(USER_ADDRESS, 10);
        dummyERC721Two.mint(OWNER_ADDRESS, 10);
        dummyERC1155One = new DummyERC1155();
        dummyERC1155One.mint(USER_ADDRESS, 10);
        dummyERC1155One.mint(OWNER_ADDRESS, 10);
        dummyERC1155Two = new DummyERC1155();
        dummyERC1155Two.mint(USER_ADDRESS, 10);
        dummyERC1155Two.mint(OWNER_ADDRESS, 10);
    }

    function testUpdateGumToken() public {
    }

    // don't let non-owner update GUM token address
    function testFailUpdateGumTokenByNonOwner() public {
    }

    function testSendERC721ToMarketplace() public {
    }

    function testSendERC1155ToMarketplace() public {
    }

    function testSendERC20ToMarketplace() public {
    }

    function testListERC721() public {
    }

    function testListERC1155() public {
    }

    // don't let non-owner list tokens
    function testFailListByNonOwner() public {
    }

    // don't allow a listing with a price of zero
    function testFailListForZero() public {
    }

    function testGetERC721Price() public {
    }

    function testGetERC1155Price() public {
    }

    function testDeleteMarketListing() public {
    }

    // don't let non-owner delete listing
    function testFailDeleteMarketListingByNonOwner() public {
    }

    function testWithdrawERC721() public {
    }

    // don't let non-owner withdraw ERC721
    function testFailWithdrawERC721ByNonOwner() public {
    }

    function testWithdrawERC1155() public {
    }

    // don't let non-owner withdraw ERC1155
    function testFailWithdrawERC1155ByNonOwner() public {
    }

    function testWithdrawERC20() public {
    }

    // don't let non-owner withdraw ERC20
    function testFailWithdrawERC20ByNonOwner() public {
    }

    function testPurchaseERC721() public {
    }

    // don't give jpegs to buyer who can't pay
    function testFailPurchaseERC721CauseBroke() public {
    }

    function testPurchaseERC1155() public {
    }

    // don't give jpegs to buyer who can't pay
    function testFailPurchaseERC1155CauseBroke() public {
    }
}
