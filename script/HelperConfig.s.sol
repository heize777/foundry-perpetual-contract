// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address usdc;
        address priceFeed;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    uint8 private constant DECIMALS = 8;
    int256 private constant ETH_USD_PRICE = 2000e8;

    uint256 private constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaETHConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilETHConfig();
        }
    }

    function getSepoliaETHConfig() public view returns (NetworkConfig memory config) {
        config = NetworkConfig({
            usdc: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607,
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilETHConfig() public returns (NetworkConfig memory config) {
        vm.startBroadcast();
        ERC20Mock usdc = new ERC20Mock();

        MockV3Aggregator priceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        vm.stopBroadcast();

        config =
            NetworkConfig({usdc: address(usdc), priceFeed: address(priceFeed), deployerKey: DEFAULT_ANVIL_PRIVATE_KEY});
    }
}
