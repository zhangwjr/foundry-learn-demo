// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MartinNFT} from "../src/MartinNFT.sol";

contract MintMartinNFT is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        address nftAddress = vm.envAddress("NFT_CONTRACT_ADDRESS");
        string memory tokenUri = vm.envString("NFT_TOKEN_URI");

        MartinNFT nft = MartinNFT(nftAddress);

        vm.startBroadcast(deployer);

        uint256 tokenId = nft.mint(deployer, tokenUri);

        console2.log("Minted tokenId:", tokenId);
        console2.log("Owner:", deployer);
        console2.log("Token URI:", tokenUri);

        vm.stopBroadcast();
    }
}
