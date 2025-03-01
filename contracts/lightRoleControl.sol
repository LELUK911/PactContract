// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.22;

contract LightRoleControl {
    address private accountant;
    address private pendingAccountant;

    event AdminshipTransferred(address indexed previousAdmin, address indexed newAdmin);


    constructor(address _accountant) {
        accountant = _accountant;
    }

    modifier onlyAccountant() {
        require(msg.sender == accountant, "Only accountant can call this function");
        _;
    }

    function transferAccountant(address _newAccountant) internal onlyAccountant {
        pendingAccountant = _newAccountant;
    }

    function acceptAccountant() internal {
        require(msg.sender == pendingAccountant, "Only pendingAccountant can call this function");
        accountant = pendingAccountant;
        pendingAccountant = address(0);
        emit AdminshipTransferred(accountant, pendingAccountant);
    }

    function getAccountant() public view returns (address) {
        return accountant;
    }

    function getPendingAccountant() public view returns (address) {
        return pendingAccountant;
    }

}