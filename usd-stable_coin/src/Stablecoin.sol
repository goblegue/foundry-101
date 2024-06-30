// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Stablecoin is ERC20Burnable, Ownable {
    //Errors
    error Stablecoin__AmountMustBeGreaterThanZero();
    error Stablecoin__BurnAmountExceedsBalance();
    error Stablecoin__NotZeroAddress();

    // Constructor
    constructor(address _owner) ERC20("Stablecoin", "STBL") Ownable(_owner) {}

    // External functions
    function mint(address to, uint256 amount) external onlyOwner returns (bool) {
        if (to == address(0)) {
            revert Stablecoin__NotZeroAddress();
        }
        if (amount <= 0) {
            revert Stablecoin__AmountMustBeGreaterThanZero();
        }
        _mint(to, amount);
        return true;
    }

    // Public functions
    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (amount <= 0) {
            revert Stablecoin__AmountMustBeGreaterThanZero();
        }
        if (amount > balance) {
            revert Stablecoin__BurnAmountExceedsBalance();
        }

        super.burn(amount);
    }

    // Internal functions

    // Private functions

    // View functions

    // Pure functions
}
