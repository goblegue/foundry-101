//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkelAirdrop {
    using SafeERC20 for IERC20;

    error MerkelAirdrop__InvalidProof();
    error MerkelAirdrop__AlreadyClaimed();

    address[] claimers;

    bytes32 private immutable i_merkelRoot;
    IERC20 private immutable i_token;
    mapping(address => bool) private s_hasClaimed;

    event Claim(address account, uint256 amount);

    constructor(bytes32 merkelRoot, IERC20 token) {
        i_merkelRoot = merkelRoot;
        i_token = token;
    }

    function claim(bytes32[] calldata proof, address account, uint256 amount) external {
        if (s_hasClaimed[account]) {
            revert MerkelAirdrop__AlreadyClaimed();
        }

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(proof, i_merkelRoot, leaf)) {
            revert MerkelAirdrop__InvalidProof();
        }
        s_hasClaimed[account] = true;
        emit Claim(account, amount);
        i_token.safeTransfer(account, amount);
    }

    function getMerkelRoot() external view returns (bytes32) {
        return i_merkelRoot;
    }

    function getTokens() external view returns (IERC20) {
        return i_token;
    }
}
