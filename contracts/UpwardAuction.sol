// SPDX-License-Identifier: Leluk911

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TimeManagment} from "./library/TimeManagement.sol";
import {console} from "hardhat/console.sol";
import "./interface/Ibond.sol";

contract UpwardAuction is Pausable, ReentrancyGuard, Ownable {
    // address del contratto di bond
    address internal bondContract;

    struct BondDetails {
        uint id;
        address issuer;
        address tokenLoan;
        uint sizeLoan;
        uint interest;
        uint[] couponMaturity;
        uint expiredBond;
        address tokenCollateral;
        uint collateral;
        uint balancLoanRepay;
        string describes;
        uint amount;
    }

    constructor(address _bondContract) Ownable(msg.sender) {
        bondContract = _bondContract;
    }

    function _moveBond(
        address _user,
        address _to,
        uint _id,
        uint _amount
    ) internal {
        IERC1155(bondContract).safeTransferFrom(_user, _to, _id, _amount, "");
    }
    function _moveErc20(
        address _token,
        address _from,
        address _to,
        uint _amount
    ) internal {
        SafeERC20.safeTransferFrom(IERC20(_token), _from, _to, _amount);
    }



    // creazione nuova asta
    
    /* mi serve:
        -> id del bond
        -> address utente
        -> tempo d'inizio
        -> tempo finale
        -> floor Price
        -> stato open/close
        -> 

        id asta
        
        id asta => utente
    */

    function _newAuction() internal {

    }
}
