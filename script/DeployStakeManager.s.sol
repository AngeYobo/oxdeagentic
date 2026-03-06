// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {StakeManager} from "../src/StakeManager.sol";

contract DeployStakeManager is Script {
    function run() external returns (StakeManager) {
        address escrow = vm.envAddress("ESCROW_ADDRESS");
        address insurancePool = vm.envAddress("INSURANCE_POOL_ADDRESS");

        vm.startBroadcast();

        StakeManager stakeManager = new StakeManager(escrow, insurancePool);

        vm.stopBroadcast();

        console2.log("StakeManager deployed at:", address(stakeManager));
        console2.log("Escrow:", escrow);
        console2.log("InsurancePool:", insurancePool);
        console2.log("MAX_SLASH_BPS:", stakeManager.MAX_SLASH_BPS());

        return stakeManager;
    }
}
