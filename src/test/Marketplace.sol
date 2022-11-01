// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "../Gum.sol";
import "../Marketplace.sol";
import "./DummyERC721.sol";
import "./DummyERC1155.sol";
import "./DummyERC20.sol";

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
    DummyERC20 dummyERC20;
    address marketplaceAddress;
    address dummyERC721OneAddress;
    address dummyERC721TwoAddress;
    address dummyERC1155OneAddress;
    address dummyERC1155TwoAddress;
    address dummyERC20Address;

    address USER_ADDRESS = address(1);
    address SPENDER_ADDRESS = address(2);
    address RANDO_ADDRESS = address(3);
    address OWNER_ADDRESS = address(4);
    address STAKING_ADDRESS = address(5);
    address NEW_GUM_TOKEN = address(6);

    function setUp() public {
        gumContract = new Gum(STAKING_ADDRESS);
        gumContract.mint(USER_ADDRESS, 1_000_000);
        gumContract.updateTransferAllowList(address(marketplaceContract), 0);
        marketplaceContract = new Marketplace(address(gumContract));
        gumContract.transferOwnership(OWNER_ADDRESS);
        marketplaceContract.transferOwnership(OWNER_ADDRESS);
        dummyERC721One = new DummyERC721();
        dummyERC721Two = new DummyERC721();
        dummyERC1155One = new DummyERC1155();
        dummyERC1155Two = new DummyERC1155();
        dummyERC20 = new DummyERC20();

        dummyERC721One.mint(USER_ADDRESS, 10);
        dummyERC721One.mint(OWNER_ADDRESS, 10);
        dummyERC721Two.mint(USER_ADDRESS, 10);
        dummyERC721Two.mint(OWNER_ADDRESS, 10);
        dummyERC1155One.mint(USER_ADDRESS, 10);
        dummyERC1155One.mint(OWNER_ADDRESS, 10);
        dummyERC1155Two.mint(USER_ADDRESS, 10);
        dummyERC1155Two.mint(OWNER_ADDRESS, 10);
        dummyERC20.mint(USER_ADDRESS, 1e24);

        marketplaceAddress = address(marketplaceContract);
        dummyERC721OneAddress = address(dummyERC721One);
        dummyERC721TwoAddress = address(dummyERC721Two);
        dummyERC1155OneAddress = address(dummyERC1155One);
        dummyERC1155TwoAddress = address(dummyERC1155Two);
        dummyERC20Address = address(dummyERC20);
    }

    function testUpdateGumToken() public {
        address oldGumToken = marketplaceContract.gumToken();
        assertEq(oldGumToken, address(gumContract));
        cheats.prank(OWNER_ADDRESS);
        marketplaceContract.updateGumToken(NEW_GUM_TOKEN);
        address newGumToken = marketplaceContract.gumToken();
        assertEq(newGumToken, NEW_GUM_TOKEN);
    }

    // don't let non-owner update GUM token address
    function testFailUpdateGumTokenByNonOwner() public {
        cheats.prank(RANDO_ADDRESS);
        marketplaceContract.updateGumToken(NEW_GUM_TOKEN);
    }

    function testSendERC721ToMarketplace() public {
        address oldOwner = dummyERC721One.ownerOf(0);
        assertEq(oldOwner, USER_ADDRESS);
        cheats.prank(USER_ADDRESS);
        dummyERC721One.safeTransferFrom(USER_ADDRESS, marketplaceAddress, 0);
        address newOwner = dummyERC721One.ownerOf(0);
        assertEq(newOwner, marketplaceAddress);
    }

    function testSendERC1155ToMarketplace() public {
        uint256 oldBalance = dummyERC1155One.balanceOf(marketplaceAddress, 0);
        assertEq(oldBalance, 0);
        cheats.prank(USER_ADDRESS);
        dummyERC1155One.safeTransferFrom(
            USER_ADDRESS,
            marketplaceAddress,
            0,
            2,
            ""
        );
        uint256 newBalance = dummyERC1155One.balanceOf(marketplaceAddress, 0);
        assertEq(newBalance, 2);
    }

    function testSendERC20ToMarketplace() public {
        uint256 oldBalance = dummyERC20.balanceOf(marketplaceAddress);
        assertEq(oldBalance, 0);
        cheats.prank(USER_ADDRESS);
        dummyERC20.transfer(marketplaceAddress, 42_069e18);
        uint256 newBalance = dummyERC20.balanceOf(marketplaceAddress);
        assertEq(newBalance, 42_069e18);
    }

    function testListERC721() public {
        uint256 oldPrice = marketplaceContract.getItemPrice(
            1,
            dummyERC721OneAddress,
            0
        );
        assertEq(oldPrice, 0);
        cheats.prank(USER_ADDRESS);
        dummyERC721One.safeTransferFrom(USER_ADDRESS, marketplaceAddress, 0);
        cheats.prank(OWNER_ADDRESS);
        marketplaceContract.listItem(1, dummyERC721OneAddress, 0, 420);
        uint256 newPrice = marketplaceContract.getItemPrice(
            1,
            dummyERC721OneAddress,
            0
        );
        assertEq(newPrice, 420e18);
    }

    function testListERC1155() public {
        uint256 oldPrice = marketplaceContract.getItemPrice(
            0,
            dummyERC1155OneAddress,
            0
        );
        assertEq(oldPrice, 0);
        cheats.prank(USER_ADDRESS);
        dummyERC1155One.safeTransferFrom(
            USER_ADDRESS,
            marketplaceAddress,
            0,
            5,
            ""
        );
        cheats.prank(OWNER_ADDRESS);
        marketplaceContract.listItem(1, dummyERC1155OneAddress, 0, 69);
        uint256 newPrice = marketplaceContract.getItemPrice(
            1,
            dummyERC1155OneAddress,
            0
        );
        assertEq(newPrice, 69e18);
    }

    // TODO
    // // make sure multiple listings don't cause trouble
    // function testListSeveralJpegs() public {
    // }

    // don't let non-owner list tokens
    function testFailListByNonOwner() public {
        cheats.prank(USER_ADDRESS);
        dummyERC1155One.safeTransferFrom(
            USER_ADDRESS,
            marketplaceAddress,
            0,
            5,
            ""
        );
        cheats.prank(RANDO_ADDRESS);
        marketplaceContract.listItem(1, dummyERC1155OneAddress, 0, 69);
    }

    // don't allow a listing with a price of zero
    function testFailListForZero() public {
        cheats.prank(USER_ADDRESS);
        dummyERC1155One.safeTransferFrom(
            USER_ADDRESS,
            marketplaceAddress,
            0,
            5,
            ""
        );
        cheats.prank(OWNER_ADDRESS);
        marketplaceContract.listItem(1, dummyERC1155OneAddress, 0, 0);
    }

    // check that price has reverted to zero
    // WARNING: be careful of false positives -- the price of any
    // random unlisted, unowned and even non-existent jpeg would
    // also be zero
    function testDeleteMarketListing() public {
        uint256 tokenId = 5;
        cheats.prank(USER_ADDRESS);
        dummyERC721One.safeTransferFrom(
            USER_ADDRESS,
            marketplaceAddress,
            tokenId
        );
        cheats.prank(OWNER_ADDRESS);
        marketplaceContract.listItem(1, dummyERC721OneAddress, tokenId, 666);
        uint256 oldPrice = marketplaceContract.getItemPrice(
            1,
            dummyERC721OneAddress,
            tokenId
        );
        assertEq(oldPrice, 666e18);
        cheats.prank(OWNER_ADDRESS);
        marketplaceContract.deleteMarketListing(
            1,
            dummyERC721OneAddress,
            tokenId
        );
        uint256 newPrice = marketplaceContract.getItemPrice(
            1,
            dummyERC721OneAddress,
            tokenId
        );
        assertEq(newPrice, 0);
    }

    // don't let non-owner delete listing
    function testFailDeleteMarketListingByNonOwner() public {
        uint256 tokenId = 5;
        cheats.prank(USER_ADDRESS);
        dummyERC721One.safeTransferFrom(
            USER_ADDRESS,
            marketplaceAddress,
            tokenId
        );
        cheats.prank(OWNER_ADDRESS);
        marketplaceContract.listItem(1, dummyERC721OneAddress, tokenId, 666);
        cheats.prank(RANDO_ADDRESS);
        marketplaceContract.deleteMarketListing(
            1,
            dummyERC721OneAddress,
            tokenId
        );
    }

    function testWithdrawERC721() public {
        uint256 tokenId = 7;
        cheats.prank(USER_ADDRESS);
        dummyERC721One.safeTransferFrom(
            USER_ADDRESS,
            marketplaceAddress,
            tokenId
        );
        address oldOwner = dummyERC721One.ownerOf(tokenId);
        assertEq(oldOwner, marketplaceAddress);
        cheats.prank(OWNER_ADDRESS);
        marketplaceContract.withdrawItems(1, dummyERC721OneAddress, tokenId, 1);
        address newOwner = dummyERC721One.ownerOf(tokenId);
        assertEq(newOwner, OWNER_ADDRESS);
    }

    // don't let non-owner withdraw ERC721
    function testFailWithdrawERC721ByNonOwner() public {
        uint256 tokenId = 4;
        cheats.prank(USER_ADDRESS);
        dummyERC721One.safeTransferFrom(
            USER_ADDRESS,
            marketplaceAddress,
            tokenId
        );
        cheats.prank(RANDO_ADDRESS);
        marketplaceContract.withdrawItems(1, dummyERC721OneAddress, tokenId, 1);
    }

    function testWithdrawERC1155() public {
        uint256 tokenId = 9;
        cheats.prank(USER_ADDRESS);
        dummyERC1155One.safeTransferFrom(
            USER_ADDRESS,
            marketplaceAddress,
            tokenId,
            5,
            ""
        );
        uint256 oldBalance = dummyERC1155One.balanceOf(
            marketplaceAddress,
            tokenId
        );
        assertEq(oldBalance, 5);
        cheats.prank(OWNER_ADDRESS);
        marketplaceContract.withdrawItems(
            0,
            dummyERC1155OneAddress,
            tokenId,
            3
        );
        uint256 newBalance = dummyERC1155One.balanceOf(
            marketplaceAddress,
            tokenId
        );
        assertEq(newBalance, 2);
    }

    // // don't let non-owner withdraw ERC1155
    // function testFailWithdrawERC1155ByNonOwner() public {
    // }

    // function testWithdrawERC20() public {
    // }

    // // don't let non-owner withdraw ERC20
    // function testFailWithdrawERC20ByNonOwner() public {
    // }

    // function testPurchaseERC721() public {
    // }

    // // don't give jpegs to buyer who can't pay
    // function testFailPurchaseERC721CauseBroke() public {
    // }

    // // don't sell a jpeg the contract holds but hasn't listed
    // function testFailPurchaseUnlistedERC721() public {
    // }

    // // don't sell a jpeg whose listing was deleted
    // function testFailPurchaseDeletedERC721() public {
    // }

    // function testPurchaseERC1155() public {
    // }

    // // don't give jpegs to buyer who can't pay
    // function testFailPurchaseERC1155CauseBroke() public {
    // }

    // // don't sell a jpeg the contract holds but hasn't listed
    // function testFailPurchaseUnlistedERC1155() public {
    // }

    // // don't sell a jpeg whose listing was deleted
    // function testFailPurchaseDeletedERC1155() public {
    // }
}
