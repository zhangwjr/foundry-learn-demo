// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MartinNFT} from "../src/MartinNFT.sol";

contract DeployMartinNFT is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        vm.startBroadcast(deployer);

        MartinNFT nft = new MartinNFT(deployer);

        console2.log("MartinNFT deployed at:", address(nft));

        vm.stopBroadcast();
    }
}
