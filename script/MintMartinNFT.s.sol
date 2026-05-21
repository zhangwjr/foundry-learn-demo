// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MartinNFT} from "../src/MartinNFT.sol";

contract MintMartinNFT is Script {
    string internal constant TOKEN_URI =
        "ipfs://bafybeibwonj54wjoujwybjmb5bry4df5ufo5bhuiau7hk7phwsuix6os4a";

    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        address nftAddress = vm.envAddress("NFT_CONTRACT_ADDRESS");

        MartinNFT nft = MartinNFT(nftAddress);

        vm.startBroadcast(deployer);

        uint256 tokenId = nft.mint(deployer, TOKEN_URI);

        console2.log("Minted tokenId:", tokenId);
        console2.log("Owner:", deployer);
        console2.log("Token URI:", TOKEN_URI);

        vm.stopBroadcast();
    }
}
