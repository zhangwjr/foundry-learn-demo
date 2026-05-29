// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1363Receiver} from "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

contract NFTMarket is IERC721Receiver, IERC1363Receiver, EIP712, Ownable, Nonces {
    using SafeERC20 for IERC20;

    IERC20 public immutable PAYMENT_TOKEN;
    IERC721 public immutable NFT;

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    mapping(address => bool) public whitelistedBuyers;

    bytes32 private constant PERMIT_WITH_BUYER_TYPEHASH =
        keccak256("permitWithBuyer(address whiteList,uint256 nonce,uint256 deadline)");

    event Listed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event Sold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event BuyerWhitelisted(address indexed buyer);

    error BuyerPermitExpired(uint256 deadline);
    error InvalidBuyerPermitSigner(address signer);
    error NotWhitelisted(address buyer);

    constructor(address paymentTokenAddress, address nftAddress)
        EIP712("NFTMarket", "1")
        Ownable(msg.sender)
    {
        require(paymentTokenAddress != address(0), "Invalid token address");
        require(nftAddress != address(0), "Invalid NFT address");
        PAYMENT_TOKEN = IERC20(paymentTokenAddress);
        NFT = IERC721(nftAddress);
    }

    function list(uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than 0");
        require(NFT.ownerOf(tokenId) == msg.sender, "Not the owner");
        require(!listings[tokenId].active, "Already listed");

        NFT.safeTransferFrom(msg.sender, address(this), tokenId);

        listings[tokenId] = Listing({seller: msg.sender, price: price, active: true});

        emit Listed(msg.sender, tokenId, price);
    }

    function buyNft(uint256 tokenId) external {
        (address seller, uint256 price) = _purchase(tokenId, msg.sender, 0, false);
        emit Sold(seller, msg.sender, tokenId, price);
    }

    /// @notice Verify admin signature and add a buyer to the whitelist.
    function permitWithBuyer(address whiteList, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        if (block.timestamp > deadline) {
            revert BuyerPermitExpired(deadline);
        }

        bytes32 structHash = keccak256(
            abi.encode(PERMIT_WITH_BUYER_TYPEHASH, whiteList, _useNonce(whiteList), deadline)
        );

        address signer = ECDSA.recover(_hashTypedDataV4(structHash), v, r, s);
        if (signer != owner()) {
            revert InvalidBuyerPermitSigner(signer);
        }

        whitelistedBuyers[whiteList] = true;
        emit BuyerWhitelisted(whiteList);
    }

    /// @notice Buy an NFT after admin offline authorization via permitWithBuyer.
    function permitBuy(uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        address buyer = msg.sender;

        if (!whitelistedBuyers[buyer]) {
            permitWithBuyer(buyer, deadline, v, r, s);
        }

        if (!whitelistedBuyers[buyer]) {
            revert NotWhitelisted(buyer);
        }

        (address seller, uint256 price) = _purchase(tokenId, buyer, 0, false);
        emit Sold(seller, buyer, tokenId, price);
    }

    /// @notice Returns the EIP-712 digest for admin to sign off-chain.
    function hashBuyerPermit(address whiteList, uint256 deadline) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_WITH_BUYER_TYPEHASH, whiteList, nonces(whiteList), deadline)
        );
        return _hashTypedDataV4(structHash);
    }

    function onTransferReceived(address, address from, uint256 value, bytes calldata data)
        external
        returns (bytes4)
    {
        require(msg.sender == address(PAYMENT_TOKEN), "Invalid caller");

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
            PAYMENT_TOKEN.safeTransfer(seller, price);
        } else {
            PAYMENT_TOKEN.safeTransferFrom(buyer, seller, price);
        }

        NFT.safeTransferFrom(address(this), buyer, tokenId);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
