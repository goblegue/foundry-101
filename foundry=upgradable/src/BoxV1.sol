//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract BoxV1{
    uint256 private value;

    function getNumber() external view returns(uint256){
        return value;
    }

    function version() external pure returns(uint256){
        return 1;
    }
}
