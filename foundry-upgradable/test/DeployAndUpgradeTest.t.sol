//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployBox} from "../script/DeployBox.s.sol";
import {UpgradeBox} from "../script/UpgradeBox.s.sol";
import {BoxV1} from "../src/BoxV1.sol";
import {BoxV2} from "../src/BoxV2.sol";

contract DeployAndUpgradeTest is Test{
    DeployBox deployer;
    UpgradeBox upgrader;

    address public OWNER = makeAddr("Owner");

    address public proxy;

    function setUp() public {
        deployer = new DeployBox();
        upgrader = new UpgradeBox();
        proxy=deployer.run();    
    }

    function testDeploy() public{
        vm.expectRevert();
        BoxV2(proxy).setNumber(10);
    }

    function testUpgrade() public{
        BoxV2 boxv2 = new BoxV2();
        upgrader.upgradeBox(proxy, address(boxv2));
        uint256 expected = 2;
        assertEq(expected, BoxV2(proxy).version());

        BoxV2(proxy).setNumber(10);
        assertEq(10, BoxV2(proxy).getNumber());
    }


}