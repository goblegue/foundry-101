// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {MetaToken} from "../src/MetaToken.sol";
import {DeployMetaToken} from "../script/DeployMetaToken.s.sol";

contract TestMetaToken is Test {

    MetaToken public token;
    DeployMetaToken public deployer;

    uint256 public constant INITIAL_SUPPLY = 100 ether;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() external {
        deployer = new DeployMetaToken();
        token = deployer.run();

        vm.prank(msg.sender);
        token.transfer(alice, INITIAL_SUPPLY);
    }

    function testTotalSupply() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function testAliceBalance() public view {
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY);
    }

    function testTransferFrom() public {
        uint256 initialAllowance = 10 ether;

        vm.prank(alice);
        token.approve(bob, initialAllowance);

        uint256 transferAmount = 5 ether;

        vm.prank(bob);
        token.transferFrom(alice, bob, transferAmount);
        assertEq(token.balanceOf(bob), transferAmount);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - transferAmount);
    }

    // Additional Tests

    function testConstructor() public {
        // Ensure the token name and symbol are set correctly
        assertEq(token.name(), "MetaToken");
        assertEq(token.symbol(), "MTK");
    }

    function testInitialMint() public {
        // Ensure the initial supply is minted to the deployer
        MetaToken newToken = new MetaToken(INITIAL_SUPPLY);
        assertEq(newToken.totalSupply(), INITIAL_SUPPLY);
        assertEq(newToken.balanceOf(address(this)), INITIAL_SUPPLY);
    }

    function testTransfer() public {
        uint256 transferAmount = 10 ether;

        vm.prank(alice);
        token.transfer(bob, transferAmount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - transferAmount);
        assertEq(token.balanceOf(bob), transferAmount);
    }

    function testApproveAndTransferFrom() public {
        uint256 allowance = 20 ether;
        uint256 transferAmount = 15 ether;

        vm.prank(alice);
        token.approve(bob, allowance);

        vm.prank(bob);
        token.transferFrom(alice, bob, transferAmount);

        assertEq(token.balanceOf(bob), transferAmount);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - transferAmount);
        assertEq(token.allowance(alice, bob), allowance - transferAmount);
    }

    function testAllowance() public {
        uint256 allowance = 50 ether;

        vm.prank(alice);
        token.approve(bob, allowance);

        assertEq(token.allowance(alice, bob), allowance);
    }
}
