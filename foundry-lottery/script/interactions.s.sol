//SPDX-Lincese-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {Raffle} from "../src/Raffle.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinator,,,,,uint256 deployerKey) = helperConfig.activeNetworkConfig();

        return createSubscription(vrfCoordinator,deployerKey);
    }

    function createSubscription(address vrfCoordinator,uint256 deployerKey) public returns (uint256) {
        // Create a subscription
        console.log("Creating a subscription on ChainId:", block.chainid);
        vm.startBroadcast(deployerKey);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Subscription ID:", subId);
        console.log("Please update the subscription ID in the HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint256) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 5 ether;
    uint96 public constant ANVIL_FUND_AMOUNT = 10000 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinator,, uint256 subscriptionId,, address link,uint256 deployerKey) = helperConfig.activeNetworkConfig();

        fundSubscription(vrfCoordinator, subscriptionId, link,deployerKey);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address link, uint256 deployerKey) public {
        // Fund the subscription
        console.log("Funding the subscription ", subscriptionId);
        console.log("Using vrfCoordinator:", vrfCoordinator);
        console.log("On:", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, ANVIL_FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(address raffleAddress, address vrfCoordinator, uint256 subscriptionId,uint256 deployerKey) public {
        // Add the consumer
        console.log("Adding a consumer to the raffle contract");
        console.log("Using vrfCoordinator:", vrfCoordinator);
        console.log("Subscription ID:", subscriptionId);
        console.log("On:", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, raffleAddress);
        vm.stopBroadcast();
    }

    function AddConsumerUsingConfig(address raffleAddress) public {
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinator,, uint256 subscriptionId,,,uint256 deployerKey) = helperConfig.activeNetworkConfig();
        addConsumer(raffleAddress, vrfCoordinator, subscriptionId,deployerKey);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        AddConsumerUsingConfig(mostRecentlyDeployed);
    }
}
