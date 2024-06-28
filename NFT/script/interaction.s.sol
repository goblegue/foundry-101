//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {BasicNFT} from "../src/BasicNFT.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract MintBasicNFT is Script {
    string constant SNOOPY_URI = "ipfs://bafybeiavgimaikcp4vcej37vxpcaaklqtktwpg3vdrk3jnrkd4a4vqq7i4/snoop%201.json";

    function run() external {
        address mostRecentlyDeployedBasicNft = DevOpsTools.get_most_recent_deployment("BasicNFT", block.chainid);
        mintNftOnContract(mostRecentlyDeployedBasicNft);
    }

    function mintNftOnContract(address basicNftAddress) public {
        vm.startBroadcast();
        BasicNFT(basicNftAddress).mintNFT(SNOOPY_URI);
        vm.stopBroadcast();
    }
}
