// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {NFTMarket} from "../src/NFTMarket.sol";

/// @notice Simulates admin signing `permitWithBuyer(address whiteList)` and whitelisting a buyer.
contract PermitNFTMarketBuyer is Script {
    function run() external {
        uint256 adminKey = vm.envOr("ADMIN_PRIVATE_KEY", vm.envOr("ANVIL_PRIVATE_KEY", uint256(0)));
        require(adminKey != 0, "Set ADMIN_PRIVATE_KEY or ANVIL_PRIVATE_KEY");

        address marketAddress = vm.envAddress("NFT_MARKET_ADDRESS");
        address buyer = vm.envAddress("WHITELIST_BUYER_ADDRESS");

        NFTMarket market = NFTMarket(marketAddress);
        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = market.hashBuyerPermit(buyer, deadline);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(adminKey, digest);

        console2.log("NFTMarket:", marketAddress);
        console2.log("Whitelist buyer:", buyer);
        console2.log("Deadline:", deadline);
        console2.log("v:", v);
        console2.logBytes32(r);
        console2.logBytes32(s);

        vm.startBroadcast(adminKey);
        market.permitWithBuyer(buyer, deadline, v, r, s);
        vm.stopBroadcast();

        console2.log("Whitelisted:", market.whitelistedBuyers(buyer));
    }
}
