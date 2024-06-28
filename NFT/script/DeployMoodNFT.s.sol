//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MoodNFT} from "../src/MoodNFT.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract DeployMoodNFT is Script {


    function run() external returns (MoodNFT) {
        string memory happySvg = vm.readFile(path:"/home/deadmanqwe/foundry-101/NFT/img/happyface.svg");
        string memory sadSvg = vm.readFile(path:"/home/deadmanqwe/foundry-101/NFT/img/sadface.svg");

        vm.startBroadcast();
        MoodNFT moodNFT = new MoodNFT(svgToImageUrI( happySvg ),svgToImageUrl( sadSvg );
        vm.stopBroadcast();
        return moodNFT;
    }

    function svgToImageURI(string memory _svg) public pure returns (string memory) 
    {    
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(_svg))));
        return string(abi.encodePacked(baseURL, svgBase64Encoded));
    }


}