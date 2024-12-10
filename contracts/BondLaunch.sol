// SPDX-License-Identifier: Leluk911

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import "./interface/Ibond.sol";
import {console} from "hardhat/console.sol";
contract BondLunch is Pausable, ReentrancyGuard, Ownable {
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

    // il bilancio di ogni utente per token specifici
    mapping(address => mapping(address => uint)) internal balanceForToken;

    // quantità di bond in vendità  nel contratto  // vale da doppio controllo
    mapping(uint => uint) internal amountInSell;
    // lista di bond in vendità nel contratto
    uint[] internal listBonds;

    event NewBondInLunch(address indexed _user, uint indexed _id, uint _amount);

    constructor(address _bondContract) Ownable(msg.sender) {
        bondContract = _bondContract;
    }

    function balanceIssuer(address _user,address _token) public view returns (uint amount){
        amount = balanceForToken[_user][_token];
    }

    function showAmountInSellForBond(uint _id) public view returns (uint amount){
        amount = amountInSell[_id];
    }

    function showBondDetail(uint _id) public returns (BondDetails memory bond) {
        (bool success, bytes memory data) = bondContract.call(
            abi.encodeWithSignature("showDeatailBondForId(uint256)", _id)
        );
        require(success, "External call failed");

        (bond) = abi.decode(data, (BondDetails));
    }
    // il titolare deposita i bond per la vendita
    function showBondLunchList()
        public
        view
        returns (uint[] memory _listBonds)
    {
        _listBonds = listBonds;
    }

    function _srcIndexListBonds(uint _id) internal view returns (uint, bool) {
        for (uint i = 0; i < listBonds.length; i++) {
            if (listBonds[i] == _id) {
                return (i, true);
            }
        }
        return (type(uint).max, false);
    }

    function findIndexBond(uint _id) public view returns(uint){
        (uint index,) = _srcIndexListBonds(_id);
        return index;
    }
    
    event IncrementBondInLunc(
        address indexed _user,
        uint indexed _id,
        uint _amount
    );

    function lunchNewBond(
        uint _id,
        uint _amount
    ) external nonReentrant whenNotPaused {
        _lunchNewBond(msg.sender, _id, _amount);
    }

    function _lunchNewBond(address _user, uint _id, uint _amount) internal {
        BondDetails memory bondDetail = showBondDetail(
            _id
        );
        
        require(bondDetail.issuer == _user, "Only iusser Bond can lunch thi function");
        require(_amount > 0, "Set correct amount");
        require(_amount <= bondDetail.amount, "Set correct amount");
        _depositBond(_user, address(this), _id, _amount);
        amountInSell[_id] = IERC1155(bondContract).balanceOf(
            address(this),
            _id
        );
        (, bool response) = _srcIndexListBonds(_id);
        if (!response) {
            listBonds.push(_id);
            emit IncrementBondInLunc(_user, _id, _amount);
        }
    }

    function _depositBond(
        address _user,
        address _to,
        uint _id,
        uint _amount
    ) internal {
        IERC1155(bondContract).safeTransferFrom(_user, _to, _id, _amount, "");
    }

    // Acquisto dei bond

    function buyBond(
        uint _id,
        uint _index,
        uint _amount
    ) external nonReentrant whenNotPaused {
        _buyBond(msg.sender, _id, _index, _amount);
    }

    event BuyBond(address indexed buyer, uint indexed amount);

    function _buyBond(
        address _user,
        uint _id,
        uint _index,
        uint _amount
    ) internal {
        require(listBonds[_index] == _id, "Bond not in sale");

        BondDetails memory bondDetail = showBondDetail(_id);

        // forse c'è una ridondanza di dati
        require(amountInSell[_id] > 0, "Bond is out Sell");
        require(_amount <= amountInSell[_id], "Digit correct amount for buy");

        _moveErc20(
            bondDetail.tokenLoan,
            _user,
            address(this),
            _amount * bondDetail.sizeLoan
        );
        amountInSell[_id] -= _amount;
        balanceForToken[bondDetail.issuer][bondDetail.tokenLoan] +=
            _amount *
            bondDetail.sizeLoan;
        bondBuyForUser[_user][_id] += _amount;
        emit BuyBond(_user, _amount);
    }

    mapping(address => mapping(uint => uint)) internal bondBuyForUser;

    function showBondForWithdraw(address _user,uint _id) external view returns(uint amount){
        amount = bondBuyForUser[_user][_id];
    }

    function withdrawBondBuy(uint _id) external nonReentrant whenNotPaused {
        uint amount = bondBuyForUser[msg.sender][_id];
        bondBuyForUser[msg.sender][_id] = 0;
        _depositBond(address(this), msg.sender, _id, amount);
    }

    function withdrawToken(address _token) external nonReentrant whenNotPaused {
        _withdrawToken(_token, msg.sender);
    }

    event WitrawToken(address indexed user, address indexed token, uint amount);
    function _withdrawToken(address _token, address _user) internal {
        uint amount = balanceForToken[msg.sender][_token];
        balanceForToken[msg.sender][_token] = 0;
        SafeERC20.safeTransfer(IERC20(_token),_user, amount);
        //_moveErc20(_token, address(this), _user, amount);
        emit WitrawToken(_user, _token, amount);
    }


    function _moveErc20(
        address _token,
        address _from,
        address _to,
        uint _amount
    ) internal {
        SafeERC20.safeTransferFrom(IERC20(_token), _from, _to, _amount);
    }

    event DeleteLunch(address indexed _user, uint indexed _id);
    function _deleteLunch(address _user, uint _id, uint index) internal {
        BondDetails memory bondDetail = showBondDetail(_id);
        require(
            bondDetail.issuer == _user,
            "Only iusser Bond can lunch this function"
        );
        require(amountInSell[_id] > 0, "Bond is not currently in sale");
        uint amountRefound = amountInSell[_id];
        amountInSell[_id] = 0;
        (, bool response) = _srcIndexListBonds(_id);
        if (response) {
            listBonds[index] = listBonds[listBonds.length - 1];
            listBonds.pop();
            // Da verificare bene le implicazioni e vurnerabilità
            _depositBond(address(this),_user, _id, amountRefound);
            emit DeleteLunch(_user, _id);
        } else {
            revert("Bond not in sell!");
        }
    }
    function deleteLunch(uint _id, uint index)external nonReentrant whenNotPaused{
        _deleteLunch(msg.sender, _id, index);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}

// considerare le cedole da riscuotere durante il periodo di detenzione
