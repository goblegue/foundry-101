// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test , console } from "forge-std/Test.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {MyGovernor} from "../src/MyGovernor.sol";

contract MyGovernerTest is Test {

    MyGovernor myGovernor;
    GovToken govToken;
    TimeLock timeLock;
    Box box;

    address public USER = makeAddr("user");

    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint256 public constant VOTING_DELAY = 1;
    uint256 public constant VOTING_PERIOD = 50400;



    uint256 public constant MIN_DELAY =  3600;
    address[] public proposers;
    address[] public executors;

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    function setUp() public{
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        govToken.delegate(USER);
        timeLock = new TimeLock(MIN_DELAY, proposers, executors);  
        myGovernor = new MyGovernor(govToken, timeLock);

        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executerRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.TIMELOCK_ADMIN_ROLE();

        timeLock.grantRole(proposerRole, address(myGovernor));
        timeLock.grantRole(executerRole, address(0));
        timeLock.revokeRole(adminRole, USER);

        vm.stopPrank();

        box = new Box(0);
        box.transferOwnership(address(timeLock));
    }

    function testCantUpdateBoxWithoutGoverance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGoveranceCanUpdateBox() public {
        uint256 valueToStore = 888;
        string memory description = " Box value to 888";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);


        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        uint256 proposalId = myGovernor.propose(targets, values, calldatas, description);

        console.log("proposal status",uint256(myGovernor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);
        
        console.log("proposal status",uint256(myGovernor.state(proposalId)));

        string memory reason ="i like green frogs";
        uint8 voteWay=1;

        vm.prank(USER);
        myGovernor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        myGovernor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        myGovernor.execute( targets, values, calldatas, descriptionHash);

        console.log("box value", box.getNumber());

        assert(box.getNumber() == valueToStore);

    }
}