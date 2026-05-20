// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

contract MyTokenScript is Script {
    function run() external {
        // `vm.getWallets()` stays empty with `forge script --account`; use the public address instead.
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");

        vm.startBroadcast(deployer);

        new MyToken(deployer);

        vm.stopBroadcast();
    }
}
