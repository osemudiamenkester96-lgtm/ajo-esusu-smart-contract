// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract DeployMockUSDC is Script {
    function run() external returns (MockUSDC) {
        vm.startBroadcast();

        MockUSDC token = new MockUSDC();

        vm.stopBroadcast();

        return token;
    }
}
