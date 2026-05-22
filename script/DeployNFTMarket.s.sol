// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";
import {MartinNFT} from "../src/MartinNFT.sol";
import {NFTMarket} from "../src/NFTMarket.sol";

contract DeployNFTMarket is Script {
    function run() external {
        address deployer;
        address tokenAddress = vm.envOr("TOKEN_ADDRESS", address(0));
        address nftAddress = vm.envOr("NFT_ADDRESS", address(0));

        uint256 privateKey = vm.envOr("ANVIL_PRIVATE_KEY", uint256(0));
        if (privateKey != 0) {
            deployer = vm.addr(privateKey);
            vm.startBroadcast(privateKey);
        } else {
            deployer = vm.envAddress("DEPLOYER_ADDRESS");
            vm.startBroadcast(deployer);
        }

        if (tokenAddress == address(0)) {
            MyToken token = new MyToken(deployer);
            tokenAddress = address(token);
            console2.log("MyToken deployed at:", tokenAddress);
        }

        if (nftAddress == address(0)) {
            MartinNFT nft = new MartinNFT(deployer);
            nftAddress = address(nft);
            console2.log("MartinNFT deployed at:", nftAddress);
        }

        NFTMarket market = new NFTMarket(tokenAddress, nftAddress);

        console2.log("NFTMarket deployed at:", address(market));
        console2.log("Payment token:", tokenAddress);
        console2.log("NFT address:", nftAddress);
        console2.log("Deployer:", deployer);

        vm.stopBroadcast();
    }
}
