//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract MoodNFT is ERC721 {


    error MoodNFT__CantFlipIfNotOwner();

    uint256 private s_counter;
    string private immutable i_happySvgImageUri;
    string private immutable i_sadSvgImageUri;

    enum Mood {
        HAPPY,
        SAD
    }

    mapping(uint256 => NFTState) private s_tokenIdToState;

    constructor(string memory happySvgUri, string memory sadSvgUri) ERC721("Mood NFT", "MN") {
        s_happySvgUri = happySvgUri;
        s_sadSvgUri = sadSvgUri;
        s_counter = 0;
    }

    function mintNFT() public {
        uint256 counter = s_counter;
        _safeMint(msg.sender, counter);
        s_tokenIdToState[counter] = Mood.HAPPY;
        s_counter++;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    function flipMood(uint256 tokenId) public {
        if(!isApprovedOrOwner(msg.sender, tokenId)) {
            revert MoodNFT__CantFlipIfNotOwner();
        }
        s_tokenIdToState[tokenId] = (s_tokenIdToState[tokenId] + 1)%2;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory imageURI;

        if (Mood.HAPPY == s_tokenIdToState[tokenId]) {
            imageURI = i_happySvgImageUri;
        } else {
            imageURI = i_sadSvgImageUri;
        }
        return string(
            abi.encodePacked(
                _baseURI(),
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            name(),
                            '", "description":"An NFT that reflects the mood of the owner, 100% on Chain!", ',
                            '"attributes": [{"trait_type": "moodiness", "value": 100}], "image":"',
                            imageURI,
                            '"}'
                        )
                    )
                )
            )
        );
    }
}
