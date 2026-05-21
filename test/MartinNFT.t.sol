// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MartinNFT} from "../src/MartinNFT.sol";

contract MartinNFTTest is Test {
    MartinNFT public nft;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");

    string internal constant TOKEN_URI =
        "ipfs://bafybeibwonj54wjoujwybjmb5bry4df5ufo5bhuiau7hk7phwsuix6os4a";

    function setUp() public {
        vm.prank(owner);
        nft = new MartinNFT(owner);
    }

    function test_Metadata() public view {
        assertEq(nft.name(), "MARTINNFT");
        assertEq(nft.symbol(), "MCYY");
    }

    function test_Mint() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(owner, TOKEN_URI);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), owner);
        assertEq(nft.balanceOf(owner), 1);
        assertEq(nft.tokenURI(tokenId), TOKEN_URI);
    }

    function test_RevertWhen_NonOwnerMints() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.mint(alice, TOKEN_URI);
    }
}
