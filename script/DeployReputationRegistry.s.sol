// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";

contract DeployReputationRegistry is Script {
    function run() external returns (ReputationRegistry) {
        address escrow = vm.envAddress("ESCROW_ADDRESS");

        vm.startBroadcast();

        ReputationRegistry registry = new ReputationRegistry(escrow);

        vm.stopBroadcast();

        console2.log("ReputationRegistry deployed at:", address(registry));
        console2.log("Escrow:", escrow);

        return registry;
    }
}
