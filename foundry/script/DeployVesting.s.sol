// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";
import {TokenVesting} from "../src/TokenVesting.sol";

contract DeployVesting is Script {
    uint256 internal constant VESTING_AMOUNT = 1_000_000 * 10 ** 18;

    function run() external {
        address deployer;
        address tokenAddress = vm.envOr("TOKEN_ADDRESS", address(0));
        address beneficiary = vm.envOr("BENEFICIARY_ADDRESS", address(0));

        uint256 privateKey = vm.envOr("ANVIL_PRIVATE_KEY", uint256(0));
        if (privateKey != 0) {
            deployer = vm.addr(privateKey);
            vm.startBroadcast(privateKey);
        } else {
            deployer = vm.envAddress("DEPLOYER_ADDRESS");
            vm.startBroadcast(deployer);
        }

        if (beneficiary == address(0)) {
            beneficiary = deployer;
        }

        if (tokenAddress == address(0)) {
            MyToken token = new MyToken(deployer);
            tokenAddress = address(token);
            console2.log("MyToken deployed at:", tokenAddress);
        }

        TokenVesting vesting = new TokenVesting(beneficiary, MyToken(tokenAddress), VESTING_AMOUNT);

        MyToken(tokenAddress).transfer(address(vesting), VESTING_AMOUNT);

        console2.log("TokenVesting deployed at:", address(vesting));
        console2.log("MyToken address:", tokenAddress);
        console2.log("Beneficiary:", beneficiary);
        console2.log("Vesting amount:", VESTING_AMOUNT);
        console2.log("Cliff ends at:", vesting.cliff());
        console2.log("Vesting ends at:", vesting.end());

        vm.stopBroadcast();
    }
}
