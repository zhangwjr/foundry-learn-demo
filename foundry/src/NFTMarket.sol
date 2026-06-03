// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1363Receiver} from "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/// @notice Gas-optimized NFT marketplace with ERC-20 payment and permit whitelist.
contract NFTMarket is IERC721Receiver, IERC1363Receiver, EIP712, Ownable, Nonces {
    IERC20 public immutable PAYMENT_TOKEN;
    IERC721 public immutable NFT;

    /// @dev Packed into one storage slot: seller (160 bits) + price (96 bits).
    struct Listing {
        address seller;
        uint96 price;
    }

    mapping(uint256 => Listing) public listings;
    mapping(address => bool) public whitelistedBuyers;

    bytes32 private constant PERMIT_WITH_BUYER_TYPEHASH =
        keccak256("permitWithBuyer(address whiteList,uint256 nonce,uint256 deadline)");

    event Listed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event Sold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event BuyerWhitelisted(address indexed buyer);

    error ZeroAddress();
    error ZeroPrice();
    error PriceTooHigh();
    error NotOwner();
    error AlreadyListed();
    error NotListed();
    error IncorrectPrice();
    error InvalidPaymentCaller();
    error TransferFailed();
    error BuyerPermitExpired(uint256 deadline);
    error InvalidBuyerPermitSigner(address signer);
    error NotWhitelisted(address buyer);

    constructor(address paymentTokenAddress, address nftAddress)
        EIP712("NFTMarket", "1")
        Ownable(msg.sender)
    {
        if (paymentTokenAddress == address(0) || nftAddress == address(0)) {
            revert ZeroAddress();
        }
        PAYMENT_TOKEN = IERC20(paymentTokenAddress);
        NFT = IERC721(nftAddress);
    }

    function list(uint256 tokenId, uint256 price) external {
        if (price == 0) revert ZeroPrice();
        if (price > type(uint96).max) revert PriceTooHigh();
        if (NFT.ownerOf(tokenId) != msg.sender) revert NotOwner();

        Listing storage listing = listings[tokenId];
        if (listing.seller != address(0)) revert AlreadyListed();

        NFT.transferFrom(msg.sender, address(this), tokenId);

        listing.seller = msg.sender;
        listing.price = uint96(price);

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
        if (msg.sender != address(PAYMENT_TOKEN)) revert InvalidPaymentCaller();

        uint256 tokenId = abi.decode(data, (uint256));
        (address seller, uint256 price) = _purchase(tokenId, from, value, true);
        emit Sold(seller, from, tokenId, price);

        return IERC1363Receiver.onTransferReceived.selector;
    }

    function _purchase(uint256 tokenId, address buyer, uint256 paymentAmount, bool tokensAlreadyReceived)
        internal
        returns (address seller, uint256 price)
    {
        Listing storage listing = listings[tokenId];
        seller = listing.seller;
        if (seller == address(0)) revert NotListed();

        price = listing.price;
        if (tokensAlreadyReceived && paymentAmount != price) revert IncorrectPrice();

        delete listings[tokenId];

        if (tokensAlreadyReceived) {
            _transferPayment(address(this), seller, price);
        } else {
            _transferPayment(buyer, seller, price);
        }

        NFT.safeTransferFrom(address(this), buyer, tokenId);
    }

    function _transferPayment(address from, address to, uint256 amount) private {
        bool success = from == address(this)
            ? PAYMENT_TOKEN.transfer(to, amount)
            : PAYMENT_TOKEN.transferFrom(from, to, amount);
        if (!success) revert TransferFailed();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
