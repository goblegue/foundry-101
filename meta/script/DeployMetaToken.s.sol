//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";

import {MetaToken} from "../src/MetaToken.sol";

contract DeployMetaToken is Script {

    uint256 public constant INITIAL_SUPPLY = 100 ether;

    function run() external returns (MetaToken) {
        vm.startBroadcast();
        MetaToken token = new MetaToken(INITIAL_SUPPLY);
        vm.stopBroadcast();
        return token;
    }
}