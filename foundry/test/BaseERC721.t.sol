// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {BaseERC721, BaseERC721Receiver} from "../src/BaseERC721.sol";

contract BaseERC721Test is Test {
    BaseERC721 internal nft;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal operator = makeAddr("operator");

    string internal constant NAME = "BaseNFT";
    string internal constant SYMBOL = "BNFT";
    string internal constant BASE_URI = "https://example.com/metadata/";

    function setUp() public {
        nft = new BaseERC721(NAME, SYMBOL, BASE_URI);
    }

    function test_ConstructorMetadata() public view {
        assertEq(nft.name(), NAME);
        assertEq(nft.symbol(), SYMBOL);
    }

    function test_SupportsInterface() public view {
        assertTrue(nft.supportsInterface(0x01ffc9a7));
        assertTrue(nft.supportsInterface(0x80ac58cd));
        assertTrue(nft.supportsInterface(0x5b5e139f));
        assertFalse(nft.supportsInterface(0xffffffff));
    }

    function test_Mint_UpdatesOwnerAndBalance() public {
        nft.mint(alice, 1);

        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(alice), 1);
    }

    function test_TokenURI_ReturnsBaseURI() public {
        nft.mint(alice, 1);
        assertEq(nft.tokenURI(1), BASE_URI);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert("ERC721: mint to the zero address");
        nft.mint(address(0), 1);
    }

    function test_RevertWhen_MintExistingToken() public {
        nft.mint(alice, 1);

        vm.expectRevert("ERC721: token already minted");
        nft.mint(bob, 1);
    }

    function test_RevertWhen_OwnerOfNonexistentToken() public {
        vm.expectRevert("ERC721: owner query for nonexistent token");
        nft.ownerOf(1);
    }

    function test_RevertWhen_BalanceOfZeroAddress() public {
        vm.expectRevert("ERC721: balance query for the zero address");
        nft.balanceOf(address(0));
    }

    function test_TransferFrom_ByOwner() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.transferFrom(alice, bob, 1);

        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
    }

    function test_SafeTransferFrom_ToReceiverContract() public {
        BaseERC721Receiver receiver = new BaseERC721Receiver();
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.safeTransferFrom(alice, address(receiver), 1);

        assertEq(nft.ownerOf(1), address(receiver));
    }

    function test_Approve_AllowsTransferByApprovedAddress() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.approve(operator, 1);

        assertEq(nft.getApproved(1), operator);

        vm.prank(operator);
        nft.transferFrom(alice, bob, 1);

        assertEq(nft.ownerOf(1), bob);
    }

    function test_SetApprovalForAll_AllowsOperatorTransfer() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        nft.setApprovalForAll(operator, true);

        assertTrue(nft.isApprovedForAll(alice, operator));

        vm.prank(operator);
        nft.transferFrom(alice, bob, 1);

        assertEq(nft.ownerOf(1), bob);
    }

    function test_RevertWhen_ApproveToCurrentOwner() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert("ERC721: approval to current owner");
        nft.approve(alice, 1);
    }

    function test_RevertWhen_UnauthorizedTransfer() public {
        nft.mint(alice, 1);

        vm.prank(bob);
        vm.expectRevert("ERC721: transfer caller is not owner nor approved");
        nft.transferFrom(alice, bob, 1);
    }

    function test_RevertWhen_SafeTransferToNonReceiverContract() public {
        nft.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert("ERC721: transfer to non ERC721Receiver implementer");
        nft.safeTransferFrom(alice, address(nft), 1);
    }
}
