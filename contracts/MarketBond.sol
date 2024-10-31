// SPDX-License-Identifier: Leluk911

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import "./interface/Ibond.sol";
contract BondMarket is Pausable, ReentrancyGuard, Ownable {
    address internal bondContract;
    address internal money; // da decidere se weth o usdc
    uint internal constant minPeriodAuction = 7 days;

    constructor(address _bondContrac, address _money) Ownable(msg.sender) {
        bondContract = _bondContrac;
        money = _money;
    }

    struct Auction {
        address owner;
        uint id;
        uint amount;
        uint startPrice;
        uint expired;
        uint pot;
        address player;
        bool open;
    }

    Auction[] internal auctions;

    mapping(address => uint) balanceUser;
    mapping(address => uint) lockBalance;

    event NewAuction(address indexed _owner, uint indexed _id, uint _amount);
    event newInstalmentPot(
        address indexed _player,
        uint indexed _index,
        uint _amountPot
    );
    event CloseAuction(uint _index, uint _time);
    event WithDrawBond(
        address indexed _user,
        uint indexed _index,
        uint indexed amount
    );
    event WithDrawMoney(address indexed _user, uint indexed amount);

    modifier outIndex(uint _index) {
        require(_index < auctions.length, "digit correct index for array");
        _;
    }

    function showAuctionsList() public view returns (Auction[] memory) {
        return auctions;
    }
    function showAuction(uint _index) public view returns (Auction memory) {
        return auctions[_index];
    }
    function newAcutionBond(
        uint _id,
        uint _amount,
        uint _startPrice,
        uint _expired
    ) external nonReentrant {
        require(_amount > 0, "Set correct bond's amount");
        require(_startPrice > 0, "Set correct start price");
        require(
            _expired > (block.timestamp + minPeriodAuction),
            "Set correct expired period"
        );
        _newAcutionBond(msg.sender, _id, _amount, _startPrice, _expired);
    }
    function instalmentPot(
        uint _index,
        uint _amount
    ) external nonReentrant outIndex(_index) {
        _instalmentPot(msg.sender, _index, _amount);
        emit newInstalmentPot(msg.sender, _index, _amount);
    }
    function closeAuction(uint _index) external nonReentrant outIndex(_index) {
        _closeAuction(msg.sender, _index);
        emit CloseAuction(_index, block.timestamp);
    }
    function withDrawBond(uint _index) external nonReentrant outIndex(_index) {
        _withDrawBond(msg.sender, _index);
    }
    function withdrawMoney(uint _amount) external nonReentrant {
        _withdrawMoney(msg.sender, _amount);
        emit WithDrawMoney(msg.sender, _amount);
    }
    // fUNZIONI PER IL DEPOSITO
    function _newAcutionBond(
        address _user,
        uint _id,
        uint _amount,
        uint _startPrice,
        uint _expired
    ) internal {
        _depositBond(_user, address(this), _id, _amount);
        _setAuctionData(_user, _id, _amount, _startPrice, _expired);
    }
    function _depositBond(
        address _user,
        address _to,
        uint _id,
        uint _amount
    ) internal {
        IERC1155(bondContract).safeTransferFrom(_user, _to, _id, _amount, "");
    }
    function _setAuctionData(
        address _owner,
        uint _id,
        uint _amount,
        uint _startPrice,
        uint _expired
    ) internal {
        Auction memory _auction = Auction(
            _owner,
            _id,
            _amount,
            _startPrice,
            _expired,
            0,
            _owner,
            true
        );
        auctions.push(_auction);
        emit NewAuction(_owner, _id, _amount);
    }
    // funzioni per puntare
    function _instalmentPot(
        address _player,
        uint _index,
        uint _amount
    ) internal {
        // prima verifichiamo se la puntata è più alta della precedente
        require(
            auctions[_index].expired < block.timestamp,
            "This auction is expired"
        );
        require(auctions[_index].open == true, "This auction is close");
        require(
            auctions[_index].pot < _amount,
            "This pot is low then already pot"
        );
        // deposito i token
        _depositErc20(_player, address(this), _amount);
        lockBalance[_player] += _amount;
        balanceUser[_player] += _amount;
        // aggiorno i dati
        //prima devo sloccare i soldi al altro player
        lockBalance[auctions[_index].player] -= auctions[_index].pot;
        auctions[_index].player = _player;
        auctions[_index].pot = _amount;
    }
    function _depositErc20(address _from, address _to, uint _amount) internal {
        SafeERC20.safeTransferFrom(IERC20(money), _from, _to, _amount);
    }
    // funzione per chiudere l'auction alla fine del processo
    function _closeAuction(address _owner, uint _index) internal {
        require(_owner == auctions[_index].owner, "Not Owner");
        require(
            auctions[_index].expired >= block.timestamp,
            "This auction is not expired"
        );
        require(auctions[_index].open == true, "This auction already close");
        auctions[_index].open = false;

        address newOwner = auctions[_index].player;
        address oldOwner = auctions[_index].owner;
        uint pot = auctions[_index].pot;

        auctions[_index].pot = 0;
        auctions[_index].owner = newOwner;

        balanceUser[newOwner] -= pot;
        lockBalance[newOwner] -= pot;

        balanceUser[oldOwner] += pot;
    }
    function _withDrawBond(address _owner, uint _index) internal {
        require(_owner == auctions[_index].owner, "Not Owner");
        require(
            auctions[_index].expired >= block.timestamp,
            "This auction is not expired"
        );
        require(auctions[_index].open == false, "This auction is Open");

        uint amountBond = auctions[_index].amount;
        auctions[_index].amount = 0;
        _depositBond(
            address(this),
            auctions[_index].owner,
            auctions[_index].id,
            amountBond
        );
        emit WithDrawBond(
            auctions[_index].owner,
            auctions[_index].id,
            amountBond
        );
    }
    // funzione per prelevare i Money
    function _withdrawMoney(address _user, uint _amount) internal {
        require(
            _amount <= balanceUser[_user] - lockBalance[_user],
            "Free balance is low for this operation"
        );
        require(
            lockBalance[_user] <= balanceUser[_user] - _amount,
            "Incorrect Operation"
        );

        balanceUser[_user] -= _amount;
        _depositErc20(address(this), _user, _amount);
    }
}
