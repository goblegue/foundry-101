// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {MyGovernor} from "../src/MyGovernor.sol";

contract MyGovernerTest is Test {

    MyGoverner myGovernor;
    GovToken govToken;
    TimeLock timeLock;
    Box box;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    function setUp() public{
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);
        
        
    }
}