//SPDX-Lincese-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {Raffle} from "../src/Raffle.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinator,,,,) = helperConfig.activeNetworkConfig();

        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256) {
        // Create a subscription
        console.log("Creating a subscription on ChainId:", block.chainid);
        vm.startBroadcast();
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
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinator,,uint256 subscriptionId,,address link) = helperConfig.activeNetworkConfig();



        fundSubscription(vrfCoordinator, subscriptionId,link);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId,address link) public {
        // Fund the subscription
        console.log("Funding the subscription ", subscriptionId);
        console.log("Using vrfCoordinator:", vrfCoordinator);
        console.log("On:", block.chainid);
        if (block.chainid == 31337){
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT,abi.encode(subscriptionId));
            vm.stopBroadcast();
        }

    }

    function run() external {
        fundSubscriptionUsingConfig();
    }


}

contract AddConsumer is script {

}
