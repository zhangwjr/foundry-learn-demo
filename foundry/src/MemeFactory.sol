// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {MemeToken} from "./MemeToken.sol";

/// @notice Deploys Meme ERC20 tokens as EIP-1167 minimal proxies to save gas.
contract MemeFactory {
    uint256 public constant PROJECT_FEE_BPS = 100; // 1%

    address public immutable owner;
    address public immutable memeImplementation;

    mapping(address => bool) public isMemeToken;

    event MemeDeployed(
        address indexed token,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );
    event MemeMinted(address indexed token, address indexed buyer, uint256 amount, uint256 cost);

    error MemeFactoryUnauthorized();
    error MemeFactoryInvalidToken();
    error MemeFactoryInsufficientPayment(uint256 required, uint256 provided);
    error MemeFactoryTransferFailed();

    constructor() {
        owner = msg.sender;
        memeImplementation = address(new MemeToken());
    }

    /// @notice Create a new Meme ERC20 clone.
    /// @param symbol Token symbol; name is fixed to "Meme".
    /// @param totalSupply Maximum mintable supply.
    /// @param perMint Amount minted per purchase.
    /// @param price Wei cost per token for each mint.
    function deployMeme(string calldata symbol, uint256 totalSupply, uint256 perMint, uint256 price)
        external
        returns (address tokenAddr)
    {
        tokenAddr = Clones.clone(memeImplementation);

        MemeToken(tokenAddr).initialize(symbol, totalSupply, perMint, price, msg.sender, address(this));
        isMemeToken[tokenAddr] = true;

        emit MemeDeployed(tokenAddr, msg.sender, symbol, totalSupply, perMint, price);
    }

    /// @notice Mint `perMint` tokens from a deployed Meme; fee is split 1% to owner and 99% to creator.
    function mintMeme(address tokenAddr) external payable {
        if (!isMemeToken[tokenAddr]) revert MemeFactoryInvalidToken();

        MemeToken token = MemeToken(tokenAddr);
        uint256 cost = token.price() * token.perMint();
        if (msg.value < cost) {
            revert MemeFactoryInsufficientPayment(cost, msg.value);
        }

        token.mint(msg.sender);

        uint256 projectFee = cost / PROJECT_FEE_BPS;
        uint256 creatorFee = cost - projectFee;

        _sendNative(owner, projectFee);
        _sendNative(token.creator(), creatorFee);

        uint256 refund = msg.value - cost;
        if (refund > 0) {
            _sendNative(msg.sender, refund);
        }

        emit MemeMinted(tokenAddr, msg.sender, token.perMint(), cost);
    }

    function _sendNative(address to, uint256 amount) internal {
        if (amount == 0) return;

        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert MemeFactoryTransferFailed();
    }
}
