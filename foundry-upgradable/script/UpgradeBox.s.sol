//SPDX-Lincense-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {BoxV1} from "../src/BoxV1.sol";
import {BoxV2} from "../src/BoxV2.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract UpgradeBox is Script {
    function run() external returns (address) {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("ERC1967Proxy", block.chainid);
        vm.startBroadcast();
        BoxV2 newbox = new BoxV2();
        vm.stopBroadcast();
        address proxy = upgradeBox(mostRecentlyDeployed, address(newbox));
        return proxy;
    }

    function upgradeBox(address _proxy, address _newImplementation) public returns (address) {
        vm.startBroadcast();
        BoxV1 proxy = BoxV1(_proxy);
        proxy.upgradeToAndCall(_newImplementation,"");
        vm.stopBroadcast();
        return address(proxy);
    }
}
