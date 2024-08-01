//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { BagleToken } from "../src/BagleTokin.sol";
import { MerkelAirdrop } from "../src/MerkelAirdrop.sol";

contract DeployMerkleAirdrop is Script {
    bytes32 public Root = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    uint256 public AMOUNT_TO_TRANSFER = 4 * 25 * 1e18;

    function deployMerkleAirdrop() public returns (MerkelAirdrop, BagleToken) {
        vm.startBroadcast();
        BagleToken token = new BagleToken();
        MerkelAirdrop airdrop = new MerkelAirdrop(Root, IERC20(token));

        token.mint(token.owner(), AMOUNT_TO_TRANSFER);
        token.transfer(address(airdrop), AMOUNT_TO_TRANSFER);
        token.transferOwnership(address(airdrop));
        vm.stopBroadcast(); 
        return (airdrop, token);
    }

    function run() external returns (MerkelAirdrop, BagleToken) {
        return deployMerkleAirdrop();
    }
}
