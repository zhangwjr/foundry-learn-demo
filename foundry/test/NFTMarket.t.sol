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

    uint256 internal constant OWNER_PRIVATE_KEY = 0xA11CE;
    address public owner = vm.addr(OWNER_PRIVATE_KEY);
    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");
    address public whitelistedBuyer = makeAddr("whitelistedBuyer");
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
        assertTrue(token.transfer(seller, 1_000 ether));
        vm.prank(owner);
        assertTrue(token.transfer(buyer, 1_000 ether));

        vm.prank(owner);
        nft.mint(seller, TOKEN_URI);
    }

    function test_Constructor() public view {
        assertEq(address(market.PAYMENT_TOKEN()), address(token));
        assertEq(address(market.NFT()), address(nft));
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
        market.buyNft(0);

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
        market.buyNft(0);

        _approveToken(buyer, 200 ether);
        vm.prank(buyer);
        market.buyNft(1);

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
        market.buyNft(0);
    }

    function test_RevertWhen_BuyWithoutTokenApproval() public {
        _listNft(seller, 0, LIST_PRICE);

        vm.prank(buyer);
        vm.expectRevert();
        market.buyNft(0);
    }

    function test_RevertWhen_BuyWithInsufficientBalance() public {
        address poorBuyer = makeAddr("poorBuyer");

        _listNft(seller, 0, LIST_PRICE);

        deal(address(token), poorBuyer, 50 ether);
        _approveToken(poorBuyer, LIST_PRICE);

        vm.prank(poorBuyer);
        vm.expectRevert();
        market.buyNft(0);
    }

    function test_RevertWhen_ConstructorWithZeroAddresses() public {
        vm.expectRevert("Invalid token address");
        new NFTMarket(address(0), address(nft));

        vm.expectRevert("Invalid NFT address");
        new NFTMarket(address(token), address(0));
    }

    function test_PermitWithBuyer_WhitelistsBuyer() public {
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signBuyerPermit(whitelistedBuyer, deadline);

        vm.expectEmit(true, false, false, false);
        emit NFTMarket.BuyerWhitelisted(whitelistedBuyer);

        market.permitWithBuyer(whitelistedBuyer, deadline, v, r, s);

        assertTrue(market.whitelistedBuyers(whitelistedBuyer));
        assertEq(market.nonces(whitelistedBuyer), 1);
    }

    function test_PermitBuy_WithSignatureBuysNft() public {
        _listNft(seller, 0, LIST_PRICE);

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signBuyerPermit(whitelistedBuyer, deadline);

        vm.prank(owner);
        assertTrue(token.transfer(whitelistedBuyer, 1_000 ether));
        _approveToken(whitelistedBuyer, LIST_PRICE);

        vm.expectEmit(true, true, true, true);
        emit NFTMarket.Sold(seller, whitelistedBuyer, 0, LIST_PRICE);

        vm.prank(whitelistedBuyer);
        market.permitBuy(0, deadline, v, r, s);

        assertTrue(market.whitelistedBuyers(whitelistedBuyer));
        assertEq(nft.ownerOf(0), whitelistedBuyer);
    }

    function test_PermitBuy_AlreadyWhitelistedSkipsSignature() public {
        _whitelistBuyer(whitelistedBuyer);
        _listNft(seller, 0, LIST_PRICE);

        vm.prank(owner);
        assertTrue(token.transfer(whitelistedBuyer, 1_000 ether));
        _approveToken(whitelistedBuyer, LIST_PRICE);

        vm.prank(whitelistedBuyer);
        market.permitBuy(0, 0, 0, bytes32(0), bytes32(0));

        assertEq(nft.ownerOf(0), whitelistedBuyer);
    }

    function test_RevertWhen_PermitWithBuyer_InvalidSigner() public {
        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = market.hashBuyerPermit(whitelistedBuyer, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xBEEF, digest);

        vm.expectRevert(abi.encodeWithSelector(NFTMarket.InvalidBuyerPermitSigner.selector, vm.addr(0xBEEF)));
        market.permitWithBuyer(whitelistedBuyer, deadline, v, r, s);
    }

    function test_RevertWhen_PermitWithBuyer_ExpiredSignature() public {
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signBuyerPermit(whitelistedBuyer, deadline);

        vm.warp(deadline + 1);

        vm.expectRevert(abi.encodeWithSelector(NFTMarket.BuyerPermitExpired.selector, deadline));
        market.permitWithBuyer(whitelistedBuyer, deadline, v, r, s);
    }

    function test_RevertWhen_PermitBuy_NotWhitelistedWithoutValidSignature() public {
        _listNft(seller, 0, LIST_PRICE);

        vm.prank(owner);
        assertTrue(token.transfer(buyer, 1_000 ether));
        _approveToken(buyer, LIST_PRICE);

        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = market.hashBuyerPermit(buyer, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xBEEF, digest);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(NFTMarket.InvalidBuyerPermitSigner.selector, vm.addr(0xBEEF)));
        market.permitBuy(0, deadline, v, r, s);
    }

    function test_RevertWhen_PermitBuy_WithoutWhitelistSignature() public {
        _listNft(seller, 0, LIST_PRICE);

        vm.prank(owner);
        assertTrue(token.transfer(buyer, 1_000 ether));
        _approveToken(buyer, LIST_PRICE);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(NFTMarket.BuyerPermitExpired.selector, uint256(0)));
        market.permitBuy(0, 0, 0, bytes32(0), bytes32(0));
    }

    function _whitelistBuyer(address whiteList) internal {
        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) = _signBuyerPermit(whiteList, deadline);
        market.permitWithBuyer(whiteList, deadline, v, r, s);
    }

    function _signBuyerPermit(address whiteList, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 digest = market.hashBuyerPermit(whiteList, deadline);
        (v, r, s) = vm.sign(OWNER_PRIVATE_KEY, digest);
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
