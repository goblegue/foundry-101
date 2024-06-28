//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {BasicNFT} from "../src/BasicNFT.sol";
import {DeployBasicNFT} from "../script/DeployBasicNFT.s.sol";

contract TestBasicNFT is Test {
    uint256 constant STARTING_BALANCE = 1000 ether;

    BasicNFT basicNFT;
    DeployBasicNFT deployBasicNFT;

    address alice = makeAddr("alice");

    function setUp() public {
        deployBasicNFT = new DeployBasicNFT();
        basicNFT = deployBasicNFT.run();
        vm.deal(alice, STARTING_BALANCE);
    }

    function testDeployment() public {
        assertEq(basicNFT.name(), "Snoopie");
        assertEq(basicNFT.symbol(), "SNP");
    }

    function testMintNFT() public {
        vm.prank(alice);
        basicNFT.mintNFT("tokenURI_1");

        assertEq(basicNFT.ownerOf(0), alice);
        assertEq(basicNFT.tokenURI(0), "tokenURI_1");
        assertEq(basicNFT.getTokenCounter(), 1);
    }

    function testTokenURI() public {
        vm.prank(alice);
        basicNFT.mintNFT("tokenURI_1");

        string memory uri = basicNFT.tokenURI(0);
        assertEq(uri, "tokenURI_1");
    }

    function testGetTokenCounter() public {
        vm.prank(alice);
        basicNFT.mintNFT("tokenURI_1");
        vm.prank(alice);
        basicNFT.mintNFT("tokenURI_2");

        uint256 counter = basicNFT.getTokenCounter();
        assertEq(counter, 2);
    }
}
