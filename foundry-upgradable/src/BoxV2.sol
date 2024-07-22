//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract BoxV2{
    uint256 private value;

    function setNumber(uint256 _value) external{
        value = _value;
    }

    function getNumber() external view returns(uint256){
        return value;
    }

    function version() external pure returns(uint256){
        return 2;
    }
}
