// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MyPermitToken} from "../src/MyPermitToken.sol";
import {TokenBank} from "../src/TokenBank.sol";

contract DeployMyPermitToken is Script {
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

        MyPermitToken token = new MyPermitToken(deployer);
        TokenBank bank = new TokenBank(address(token));

        console2.log("MyPermitToken deployed at:", address(token));
        console2.log("TokenBank deployed at:", address(bank));
        console2.log("Deployer:", deployer);

        vm.stopBroadcast();
    }
}
