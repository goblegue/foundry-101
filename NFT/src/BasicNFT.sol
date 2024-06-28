//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BasicNFT is ERC721 {
    uint256 private S_tokenCounter;

    mapping(uint256 => string) private s_tokenIdToURIs;

    constructor() ERC721("Snoopie", "SNP") {
        S_tokenCounter = 0;
    }

    function mintNFT(string memory _tokenURI) public {
        uint256 tokenId = S_tokenCounter;
        s_tokenIdToURIs[tokenId] = _tokenURI;
        _safeMint(msg.sender, tokenId);
        S_tokenCounter++;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return s_tokenIdToURIs[tokenId];
    }

    function getTokenCounter() external view returns (uint256) {
        return S_tokenCounter;
    }
}
