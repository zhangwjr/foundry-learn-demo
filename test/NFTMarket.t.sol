// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";
import {MartinNFT} from "../src/MartinNFT.sol";
import {NFTMarket} from "../src/NFTMarket.sol";

contract NFTMarketTest is Test {
    MyToken public token;
    MartinNFT public nft;
    NFTMarket public market;

    address public owner = makeAddr("owner");
    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");
    address public other = makeAddr("other");

    string internal constant TOKEN_URI =
        "ipfs://bafybeibwonj54wjoujwybjmb5bry4df5ufo5bhuiau7hk7phwsuix6os4a";

    uint256 internal constant LIST_PRICE = 100 ether;

    function setUp() public {
        vm.startPrank(owner);
        token = new MyToken(owner);
        nft = new MartinNFT(owner);
        market = new NFTMarket(address(token), address(nft));
        vm.stopPrank();

        vm.prank(owner);
        token.transfer(seller, 1_000 ether);
        vm.prank(owner);
        token.transfer(buyer, 1_000 ether);

        vm.prank(owner);
        nft.mint(seller, TOKEN_URI);
    }

    function test_Constructor() public view {
        assertEq(address(market.paymentToken()), address(token));
        assertEq(address(market.nft()), address(nft));
    }

    function test_List_TransfersNftToMarket() public {
        _approveNft(seller, 0);

        vm.prank(seller);
        market.list(0, LIST_PRICE);

        (address listedSeller, uint256 price, bool active) = market.listings(0);
        assertEq(listedSeller, seller);
        assertEq(price, LIST_PRICE);
        assertTrue(active);
        assertEq(nft.ownerOf(0), address(market));
    }

    function test_List_EmitsListedEvent() public {
        _approveNft(seller, 0);

        vm.expectEmit(true, true, false, true);
        emit NFTMarket.Listed(seller, 0, LIST_PRICE);

        vm.prank(seller);
        market.list(0, LIST_PRICE);
    }

    function test_BuyNFT_TransfersTokenAndNft() public {
        _listNft(seller, 0, LIST_PRICE);
        _approveToken(buyer, LIST_PRICE);

        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);

        vm.expectEmit(true, true, true, true);
        emit NFTMarket.Sold(seller, buyer, 0, LIST_PRICE);

        vm.prank(buyer);
        market.buyNFT(0);

        assertEq(token.balanceOf(seller), sellerBalanceBefore + LIST_PRICE);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - LIST_PRICE);
        assertEq(nft.ownerOf(0), buyer);

        (address listedSeller, uint256 price, bool active) = market.listings(0);
        assertEq(listedSeller, address(0));
        assertEq(price, 0);
        assertFalse(active);
    }

    function test_BuyNFTViaTransferAndCall() public {
        _listNft(seller, 0, LIST_PRICE);

        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);

        vm.expectEmit(true, true, true, true);
        emit NFTMarket.Sold(seller, buyer, 0, LIST_PRICE);

        vm.prank(buyer);
        token.transferAndCall(address(market), LIST_PRICE, abi.encode(0));

        assertEq(token.balanceOf(seller), sellerBalanceBefore + LIST_PRICE);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - LIST_PRICE);
        assertEq(nft.ownerOf(0), buyer);
        assertEq(token.balanceOf(address(market)), 0);
    }

    function test_RevertWhen_TransferAndCallWithWrongPrice() public {
        _listNft(seller, 0, LIST_PRICE);

        vm.prank(buyer);
        vm.expectRevert("Incorrect price");
        token.transferAndCall(address(market), 50 ether, abi.encode(0));
    }

    function test_RevertWhen_TransferAndCallNotListed() public {
        vm.prank(buyer);
        vm.expectRevert("Not listed");
        token.transferAndCall(address(market), LIST_PRICE, abi.encode(0));
    }

    function test_BuyNFT_MultipleListings() public {
        vm.prank(owner);
        nft.mint(seller, TOKEN_URI);

        _listNft(seller, 0, LIST_PRICE);
        _listNft(seller, 1, 200 ether);

        _approveToken(buyer, LIST_PRICE);
        vm.prank(buyer);
        market.buyNFT(0);

        _approveToken(buyer, 200 ether);
        vm.prank(buyer);
        market.buyNFT(1);

        assertEq(nft.ownerOf(0), buyer);
        assertEq(nft.ownerOf(1), buyer);
        assertEq(token.balanceOf(seller), 1_000 ether + LIST_PRICE + 200 ether);
    }

    function test_RevertWhen_ListWithZeroPrice() public {
        _approveNft(seller, 0);

        vm.prank(seller);
        vm.expectRevert("Price must be greater than 0");
        market.list(0, 0);
    }

    function test_RevertWhen_ListNotOwner() public {
        vm.prank(other);
        vm.expectRevert("Not the owner");
        market.list(0, LIST_PRICE);
    }

    function test_RevertWhen_ListWithoutApproval() public {
        vm.prank(seller);
        vm.expectRevert();
        market.list(0, LIST_PRICE);
    }

    function test_RevertWhen_ListTwice() public {
        _listNft(seller, 0, LIST_PRICE);

        vm.prank(seller);
        vm.expectRevert("Not the owner");
        market.list(0, LIST_PRICE);
    }

    function test_RevertWhen_BuyNotListed() public {
        vm.prank(buyer);
        vm.expectRevert("Not listed");
        market.buyNFT(0);
    }

    function test_RevertWhen_BuyWithoutTokenApproval() public {
        _listNft(seller, 0, LIST_PRICE);

        vm.prank(buyer);
        vm.expectRevert();
        market.buyNFT(0);
    }

    function test_RevertWhen_BuyWithInsufficientBalance() public {
        address poorBuyer = makeAddr("poorBuyer");

        _listNft(seller, 0, LIST_PRICE);

        deal(address(token), poorBuyer, 50 ether);
        _approveToken(poorBuyer, LIST_PRICE);

        vm.prank(poorBuyer);
        vm.expectRevert();
        market.buyNFT(0);
    }

    function test_RevertWhen_ConstructorWithZeroAddresses() public {
        vm.expectRevert("Invalid token address");
        new NFTMarket(address(0), address(nft));

        vm.expectRevert("Invalid NFT address");
        new NFTMarket(address(token), address(0));
    }

    function _listNft(address from, uint256 tokenId, uint256 price) internal {
        _approveNft(from, tokenId);
        vm.prank(from);
        market.list(tokenId, price);
    }

    function _approveNft(address owner_, uint256 tokenId) internal {
        vm.prank(owner_);
        nft.approve(address(market), tokenId);
    }

    function _approveToken(address owner_, uint256 amount) internal {
        vm.prank(owner_);
        token.approve(address(market), amount);
    }
}
