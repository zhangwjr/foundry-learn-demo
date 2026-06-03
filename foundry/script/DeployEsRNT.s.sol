// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {esRNT} from "../src/esRNT.sol";

contract DeployEsRNT is Script {
    function run() external {
        address deployer;
        uint256 privateKey = vm.envOr("ANVIL_PRIVATE_KEY", uint256(0));

        if (privateKey != 0) {
            deployer = vm.addr(privateKey);
            vm.startBroadcast(privateKey);
        } else {
            deployer = vm.envAddress("DEPLOYER_ADDRESS");
            vm.startBroadcast(deployer);
        }

        esRNT token = new esRNT();

        console2.log("esRNT deployed at:", address(token));
        console2.log("Deployer:", deployer);

        vm.stopBroadcast();
    }
}
