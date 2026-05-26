// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";
import {TokenBank} from "../src/TokenBank.sol";

contract DeployTokenBank is Script {
    function run() external {
        address deployer;
        address tokenAddress = vm.envOr("TOKEN_ADDRESS", address(0));

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

        TokenBank bank = new TokenBank(tokenAddress);

        console2.log("TokenBank deployed at:", address(bank));
        console2.log("Token address:", tokenAddress);
        console2.log("Deployer:", deployer);

        vm.stopBroadcast();
    }
}
