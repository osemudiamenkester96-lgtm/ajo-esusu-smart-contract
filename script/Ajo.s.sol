// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Ajo} from "../src/Ajo.sol";

contract AjoScript is Script {
    function run() external returns (Ajo) {
        // Replace this with the ERC-20 token address you want to use.
        address token = vm.envAddress("TOKEN_ADDRESS");

        uint256 contributionAmount = vm.envUint("CONTRIBUTION_AMOUNT");
        uint256 cycleDuration = vm.envUint("CYCLE_DURATION");
        uint256 maxMembers = vm.envUint("MAX_MEMBERS");

        vm.startBroadcast();

        Ajo ajo = new Ajo(
            token,
            contributionAmount,
            cycleDuration,
            maxMembers
        );

        vm.stopBroadcast();

        return ajo;
    }
}