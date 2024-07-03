//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Stablecoin} from "../src/Stablecoin.sol";
import {SCEngine} from "../src/SCEngine.sol";

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeploySC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (Stablecoin, SCEngine, HelperConfig) {
        HelperConfig hc = new HelperConfig();
        (address wethPriceFeed, address wbtcPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            hc.activeConfig();

        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethPriceFeed, wbtcPriceFeed];

        vm.startBroadcast(deployerKey);
        Stablecoin sc = new Stablecoin(vm.addr(deployerKey));
        SCEngine scEngine = new SCEngine(tokenAddresses, priceFeedAddresses, address(sc));
        sc.transferOwnership(address(scEngine));
        vm.stopBroadcast();

        return (sc, scEngine, hc);
    }
}
