// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {

    constructor(uint _initialSupply,string memory _name, string memory _ticker) ERC20(_name, _ticker){
        _mint(msg.sender, _initialSupply);
    }
}