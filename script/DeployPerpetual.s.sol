// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script} from "forge-std/Script.sol";
import {Perpetual} from "../src/Perpetual.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployPerpetual is Script {
    function run() external returns (Perpetual perp, HelperConfig config) {
        config = new HelperConfig();
        (address usdc, address priceFeed, uint256 deployerKey) = config.activeNetworkConfig();
        vm.startBroadcast(deployerKey);
        perp = new Perpetual(
            usdc, // USDC
            priceFeed
        );
        vm.stopBroadcast();
    }
}
