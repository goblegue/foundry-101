//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

contract PatrickToken {

    error PatrickToken__InsufficientFunds();
    error PatrickToken__TransferFailed();

    mapping(address => uint256) private s_balances;


    function name() public pure returns (string memory) {
        return "Patrick Token";
    }

    function totalSupply() public pure returns (uint256) {
        return 100 ether;
    }

    function decimal() public pure returns (uint8) {
        return 18;
    }

    function balaceOf(address _owner) public view returns (uint256) {
        return s_balances[_owner];
    }

    function transfer(address _to,uint256 _value) public returns (bool) {
        if(s_balances[msg.sender] >= _value){
            revert PatrickToken__InsufficientFunds();
        }
        uint256 previousBalances = s_balances[msg.sender] + s_balances[_to];
        s_balances[msg.sender] -= _value;
        s_balances[_to] += _value;
        if(s_balances[msg.sender] + s_balances[_to] == previousBalances){
            return true;
        }
        else{
            revert PatrickToken__TransferFailed() ;
            }

    }



}
