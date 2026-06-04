// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MartinNFT} from "../src/MartinNFT.sol";
import {MyPermitToken} from "../src/MyPermitToken.sol";
import {WhiteListMerkleNFTMarket} from "../src/WhiteListMerkleNFTMarket.sol";

contract WhiteListMerkleNFTMarketTest is Test {
    MyPermitToken public token;
    MartinNFT public nft;
    WhiteListMerkleNFTMarket public market;

    uint256 internal constant OWNER_KEY = 0xA11CE;
    uint256 internal constant WHITELISTED_BUYER_KEY = 0xB0B;
    uint256 internal constant OTHER_BUYER_KEY = 0xC0C;

    address public owner = vm.addr(OWNER_KEY);
    address public seller = makeAddr("seller");
    address public whitelistedBuyer = vm.addr(WHITELISTED_BUYER_KEY);
    address public otherBuyer = vm.addr(OTHER_BUYER_KEY);

    string internal constant TOKEN_URI =
        "ipfs://bafybeibwonj54wjoujwybjmb5bry4df5ufo5bhuiau7hk7phwsuix6os4a";

    uint256 internal constant LIST_PRICE = 100 ether;
    uint256 internal constant WHITELIST_PRICE = LIST_PRICE / 2;

    bytes32[] internal leaves;
    bytes32 internal merkleRoot;

    function setUp() public {
        address[] memory accounts = new address[](2);
        accounts[0] = whitelistedBuyer;
        accounts[1] = makeAddr("otherWhitelisted");
        (merkleRoot, leaves) = _buildMerkleTree(accounts);

        vm.startPrank(owner);
        token = new MyPermitToken(owner);
        nft = new MartinNFT(owner);
        market = new WhiteListMerkleNFTMarket(address(token), address(nft), merkleRoot);
        vm.stopPrank();

        vm.prank(owner);
        token.transfer(seller, 1_000 ether);
        vm.prank(owner);
        token.transfer(whitelistedBuyer, 1_000 ether);

        vm.prank(owner);
        nft.mint(seller, TOKEN_URI);
    }

    function test_Multicall_PermitPrePayAndBuyNFTInWhitelist() public {
        _listNft(seller, 0, LIST_PRICE);

        uint256 deadline = block.timestamp + 1 days;
        (uint8 v, bytes32 r, bytes32 s) =
            _signTokenPermit(whitelistedBuyer, address(market), WHITELIST_PRICE, deadline, WHITELISTED_BUYER_KEY);

        bytes32[] memory proof = _proofFor(whitelistedBuyer);

        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(whitelistedBuyer);

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            WhiteListMerkleNFTMarket.permitPrePay.selector, 0, deadline, v, r, s
        );
        calls[1] = abi.encodeWithSelector(WhiteListMerkleNFTMarket.buyNFTInWhitelist.selector, 0, proof);

        vm.expectEmit(true, true, true, true);
        emit WhiteListMerkleNFTMarket.Sold(seller, whitelistedBuyer, 0, WHITELIST_PRICE);

        vm.prank(whitelistedBuyer);
        market.multicall(calls);

        assertEq(token.balanceOf(seller), sellerBalanceBefore + WHITELIST_PRICE);
        assertEq(token.balanceOf(whitelistedBuyer), buyerBalanceBefore - WHITELIST_PRICE);
        assertEq(nft.ownerOf(0), whitelistedBuyer);

        (address listedSeller, uint256 price) = market.listings(0);
        assertEq(listedSeller, address(0));
        assertEq(price, 0);
    }

    function test_RevertWhen_BuyNFTInWhitelist_NotInMerkleTree() public {
        _listNft(seller, 0, LIST_PRICE);

        bytes32[] memory proof = _proofFor(whitelistedBuyer);

        vm.prank(otherBuyer);
        vm.expectRevert(abi.encodeWithSelector(WhiteListMerkleNFTMarket.NotInWhitelist.selector, otherBuyer));
        market.buyNFTInWhitelist(0, proof);
    }

    function _listNft(address from, uint256 tokenId, uint256 price) internal {
        vm.prank(from);
        nft.approve(address(market), tokenId);
        vm.prank(from);
        market.list(tokenId, price);
    }

    function _signTokenPermit(
        address owner_,
        address spender,
        uint256 value,
        uint256 deadline,
        uint256 privateKey
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner_,
                spender,
                value,
                token.nonces(owner_),
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (v, r, s) = vm.sign(privateKey, digest);
    }

    function _proofFor(address account) internal view returns (bytes32[] memory proof) {
        bytes32 leaf = market.whitelistLeaf(account);
        uint256 index;
        for (uint256 i = 0; i < leaves.length; i++) {
            if (leaves[i] == leaf) {
                index = i;
                break;
            }
        }
        proof = _getProof(leaves, index);
    }

    function _buildMerkleTree(address[] memory accounts)
        internal
        pure
        returns (bytes32 root, bytes32[] memory treeLeaves)
    {
        treeLeaves = new bytes32[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            treeLeaves[i] = keccak256(abi.encodePacked(accounts[i]));
        }
        treeLeaves = _sortLeaves(treeLeaves);
        root = _computeRoot(treeLeaves);
    }

    function _computeRoot(bytes32[] memory nodes) internal pure returns (bytes32) {
        if (nodes.length == 1) return nodes[0];

        bytes32[] memory next = new bytes32[]((nodes.length + 1) / 2);
        uint256 write;
        for (uint256 i = 0; i < nodes.length; i += 2) {
            if (i + 1 < nodes.length) {
                next[write++] = _hashPair(nodes[i], nodes[i + 1]);
            } else {
                next[write++] = nodes[i];
            }
        }
        bytes32[] memory trimmed = new bytes32[](write);
        for (uint256 i = 0; i < write; i++) {
            trimmed[i] = next[i];
        }
        return _computeRoot(trimmed);
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b
            ? keccak256(abi.encodePacked(a, b))
            : keccak256(abi.encodePacked(b, a));
    }

    function _sortLeaves(bytes32[] memory unsorted) internal pure returns (bytes32[] memory sorted) {
        sorted = unsorted;
        for (uint256 i = 0; i < sorted.length; i++) {
            for (uint256 j = i + 1; j < sorted.length; j++) {
                if (uint256(sorted[i]) > uint256(sorted[j])) {
                    (sorted[i], sorted[j]) = (sorted[j], sorted[i]);
                }
            }
        }
    }

    function _getProof(bytes32[] memory treeLeaves, uint256 index) internal pure returns (bytes32[] memory proof) {
        proof = new bytes32[](0);
        bytes32[] memory layer = treeLeaves;
        uint256 idx = index;

        while (layer.length > 1) {
            bytes32 sibling;
            if (idx % 2 == 0) {
                if (idx + 1 < layer.length) {
                    sibling = layer[idx + 1];
                } else {
                    break;
                }
            } else {
                sibling = layer[idx - 1];
            }

            proof = _append(proof, sibling);

            bytes32[] memory next = new bytes32[]((layer.length + 1) / 2);
            uint256 write;
            for (uint256 i = 0; i < layer.length; i += 2) {
                if (i + 1 < layer.length) {
                    next[write++] = _hashPair(layer[i], layer[i + 1]);
                } else {
                    next[write++] = layer[i];
                }
            }
            bytes32[] memory trimmed = new bytes32[](write);
            for (uint256 i = 0; i < write; i++) {
                trimmed[i] = next[i];
            }
            layer = trimmed;
            idx /= 2;
        }
    }

    function _append(bytes32[] memory arr, bytes32 value) internal pure returns (bytes32[] memory out) {
        out = new bytes32[](arr.length + 1);
        for (uint256 i = 0; i < arr.length; i++) {
            out[i] = arr[i];
        }
        out[arr.length] = value;
    }
}
