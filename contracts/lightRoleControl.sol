// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.22;

contract LightRoleControl {
    address private accountant;
    address private pendingAccountant;

    event AccountantshipTransferred(address indexed previousAdmin, address indexed accountant);


    constructor(address _accountant) {
        accountant = _accountant;
    }

  



    function acceptAccountant() internal {
        require(msg.sender == pendingAccountant, "Only pendingAccountant can call this function");
        accountant = pendingAccountant;
        pendingAccountant = address(0);
        emit AccountantshipTransferred(accountant, pendingAccountant);
    }

    function getAccountant() external view returns (address) {
        return accountant;
    }

    function getPendingAccountant() external view returns (address) {
        return pendingAccountant;
    }

}