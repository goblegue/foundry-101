//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MerkelAirdrop is EIP712 {
    using SafeERC20 for IERC20;

    error MerkelAirdrop__InvalidProof();
    error MerkelAirdrop__AlreadyClaimed();
    error MerkelAirdrop__InvalidSignature();

   

    bytes32 private immutable i_merkelRoot;
    IERC20 private immutable i_token;
    mapping(address => bool) private s_hasClaimed;

    bytes32 private constant MESSAGE_TYPEHASH = keccak256("AirdropClaim(address account,uint256 amount)");

    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    event Claim(address account, uint256 amount);

    constructor(bytes32 merkelRoot, IERC20 token) EIP712("MerkelAirdrop", "1") {
        i_merkelRoot = merkelRoot;
        i_token = token;
    }

    function claim(bytes32[] calldata proof, address account, uint256 amount, uint8 v, bytes32 r, bytes32 s) external {
        if (s_hasClaimed[account]) {
            revert MerkelAirdrop__AlreadyClaimed();
        }
        if (!isValidSignature(account, getMessageHash(account, amount), v, r, s)) {
            revert MerkelAirdrop__InvalidSignature();
        }

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(proof, i_merkelRoot, leaf)) {
            revert MerkelAirdrop__InvalidProof();
        }
        s_hasClaimed[account] = true;
        emit Claim(account, amount);
        i_token.safeTransfer(account, amount);
    }

    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({ account: account, amount: amount })))
        );
    }

    function isValidSignature(
        address account,
        bytes32 digest,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
        pure
        returns (bool)
    {
        (address actualSigner,,) = ECDSA.tryRecover(digest, v, r, s);
        return actualSigner == account;
    }

    function getMerkelRoot() external view returns (bytes32) {
        return i_merkelRoot;
    }

    function getTokens() external view returns (IERC20) {
        return i_token;
    }
}
