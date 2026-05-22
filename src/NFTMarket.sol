// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1363Receiver} from "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";

contract NFTMarket is IERC721Receiver, IERC1363Receiver {
    using SafeERC20 for IERC20;

    IERC20 public immutable paymentToken;
    IERC721 public immutable nft;

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) public listings;

    event Listed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event Sold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);

    constructor(address paymentTokenAddress, address nftAddress) {
        require(paymentTokenAddress != address(0), "Invalid token address");
        require(nftAddress != address(0), "Invalid NFT address");
        paymentToken = IERC20(paymentTokenAddress);
        nft = IERC721(nftAddress);
    }

    function list(uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than 0");
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(!listings[tokenId].active, "Already listed");

        nft.safeTransferFrom(msg.sender, address(this), tokenId);

        listings[tokenId] = Listing({seller: msg.sender, price: price, active: true});

        emit Listed(msg.sender, tokenId, price);
    }

    function buyNFT(uint256 tokenId) external {
        (address seller, uint256 price) = _purchase(tokenId, msg.sender, 0, false);
        emit Sold(seller, msg.sender, tokenId, price);
    }

    function onTransferReceived(address, address from, uint256 value, bytes calldata data)
        external
        returns (bytes4)
    {
        require(msg.sender == address(paymentToken), "Invalid caller");

        uint256 tokenId = abi.decode(data, (uint256));
        (address seller, uint256 price) = _purchase(tokenId, from, value, true);
        emit Sold(seller, from, tokenId, price);

        return IERC1363Receiver.onTransferReceived.selector;
    }

    function _purchase(uint256 tokenId, address buyer, uint256 paymentAmount, bool tokensAlreadyReceived)
        internal
        returns (address seller, uint256 price)
    {
        Listing memory listing = listings[tokenId];
        require(listing.active, "Not listed");

        seller = listing.seller;
        price = listing.price;

        if (tokensAlreadyReceived) {
            require(paymentAmount == price, "Incorrect price");
        }

        delete listings[tokenId];

        if (tokensAlreadyReceived) {
            paymentToken.safeTransfer(seller, price);
        } else {
            paymentToken.safeTransferFrom(buyer, seller, price);
        }

        nft.safeTransferFrom(address(this), buyer, tokenId);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
