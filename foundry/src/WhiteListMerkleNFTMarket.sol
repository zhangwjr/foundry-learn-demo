// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {MyPermitToken} from "./MyPermitToken.sol";

/// @notice NFT marketplace with Merkle whitelist buyers paying 50% via MyPermitToken permit.
contract WhiteListMerkleNFTMarket is IERC721Receiver, Multicall, Ownable {
    MyPermitToken public immutable PAYMENT_TOKEN; // 支付Token合约地址
    IERC721 public immutable NFT; // NFT合约地址
    bytes32 public immutable MERKLE_ROOT; // 白名单的根节点

    /// @dev Packed into one storage slot: seller (160 bits) + price (96 bits).
    struct Listing {
        address seller;
        uint96 price;
    }
    // 存储NFT的列表
    mapping(uint256 => Listing) public listings;
    // 上架事件
    event Listed(address indexed seller, uint256 indexed tokenId, uint256 price);
    // 购买事件
    event Sold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);

    error ZeroAddress(); // 地址为0
    error ZeroPrice(); // 价格为0
    error PriceTooHigh(); // 价格太高
    error NotOwner(); // 不是所有者
    error AlreadyListed(); // 已经上架
    error NotListed(); // 没有上架
    error TransferFailed(); // 转账失败
    error NotInWhitelist(address buyer); // 买家不在白名单中

    // 构造函数, 初始化支付Token合约地址, NFT合约地址, 白名单的根节点
    constructor(address paymentTokenAddress, address nftAddress, bytes32 merkleRoot)
        Ownable(msg.sender)
    {
        // 如果支付Token合约地址或NFT合约地址为0, 则抛出ZeroAddress错误
        if (paymentTokenAddress == address(0) || nftAddress == address(0)) {
            revert ZeroAddress();
        }
        // 初始化支付Token合约地址
        PAYMENT_TOKEN = MyPermitToken(paymentTokenAddress);
        // 初始化NFT合约地址
        NFT = IERC721(nftAddress);
        // 初始化白名单的根节点
        MERKLE_ROOT = merkleRoot;
    }
    // 生成白名单的叶子节点
    /// @notice Leaf = keccak256(abi.encodePacked(account)), tree built with sorted commutative keccak256 pairs (OpenZeppelin MerkleProof).
    function whitelistLeaf(address account) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }
    // 卖家上架NFT, 上架价格为price
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

    // 买家支付50%的购买价格, 使用MyPermitToken.permit() 方法进行支付
    /// @notice ERC-2612 permit so the market can pull the whitelist (50%) price from the buyer.
    function permitPrePay(uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        Listing storage listing = listings[tokenId];
        if (listing.seller == address(0)) revert NotListed();

        uint256 amount = uint256(listing.price) / 2;
        PAYMENT_TOKEN.permit(msg.sender, address(this), amount, deadline, v, r, s);
    }

    // 买家购买NFT, 使用MerkleProof.verify() 方法验证买家是否在白名单中
    /// @notice Buy at 50% of list price when `msg.sender` is in the Merkle whitelist.
    function buyNFTInWhitelist(uint256 tokenId, bytes32[] calldata proof) external {
        if (!MerkleProof.verify(proof, MERKLE_ROOT, whitelistLeaf(msg.sender))) {
            revert NotInWhitelist(msg.sender);
        }

        (address seller, uint256 price) = _purchase(tokenId, msg.sender);
        emit Sold(seller, msg.sender, tokenId, price);
    }
    // 购买NFT, 从列表中删除NFT, 并转移NFT到买家
    function _purchase(uint256 tokenId, address buyer) internal returns (address seller, uint256 price) {
        Listing storage listing = listings[tokenId];
        seller = listing.seller;
        if (seller == address(0)) revert NotListed();

        price = uint256(listing.price) / 2;
        delete listings[tokenId];

        bool success = PAYMENT_TOKEN.transferFrom(buyer, seller, price);
        if (!success) revert TransferFailed();

        NFT.safeTransferFrom(address(this), buyer, tokenId);
    }

    // 接收NFT, 返回IERC721Receiver.onERC721Received.selector
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
