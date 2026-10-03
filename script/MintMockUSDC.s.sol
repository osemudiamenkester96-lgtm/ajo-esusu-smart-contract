// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {MockUSDC} from "../src/MockUSDC.sol";

contract MintMockUSDC is Script {
    function run() external {
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address recipient = vm.envAddress("WALLET_ADDRESS");

        uint256 amount = vm.envUint("MINT_AMOUNT");

        vm.startBroadcast();

        MockUSDC(tokenAddress).mint(recipient, amount);

        vm.stopBroadcast();
    }
}
