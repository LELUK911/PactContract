// SPDX-License-Identifier: Leluk911

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./interface/Ibond.sol";

import {console} from "hardhat/console.sol";

//! AGGIUNGERE IL REQUIRE PER LE PAUSE
contract DownwardAuction is
    ERC165,
    Pausable,
    ReentrancyGuard,
    Ownable,
    IERC1155Receiver
{
    address internal bondContract;
    address internal money; // da decidere se weth o usdc
    uint internal constant minPeriodAuction = 7 days;
    uint internal contractBalance;
    uint internal coolDown;

    constructor(
        address _bondContrac,
        address _money,
        uint _fixedFee,
        uint _priceThreshold,
        uint _dinamicFee
    ) Ownable(msg.sender) {
        bondContract = _bondContrac;
        money = _money;

        feeSystem.fixedFee = _fixedFee;
        feeSystem.priceThreshold = _priceThreshold;
        feeSystem.dinamicFee = _dinamicFee;
    }
    // TODO Struttura modificata
    struct Auction {
        address owner;
        uint id;
        uint amount;
        uint startPrice;
        uint expired;
        uint pot;
        address player;
        bool open;
        uint tolleratedDiscount; // todo
        uint[] penality;
    }
    struct FeeSystem {
        uint fixedFee;
        uint priceThreshold;
        uint dinamicFee;
    }
    struct FeeSeller {
        uint[] echelons;
        uint[] fees;
    }
    FeeSeller internal feeSeller;
    FeeSystem internal feeSystem;
    Auction[] internal auctions;

    mapping(address => uint) balanceUser; // non mi convince
    mapping(address => uint) lockBalance;
    mapping(address => mapping(uint => uint)) internal lastPotTime;

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
    event PaidFee(uint _amount);

    modifier outIndex(uint _index) {
        require(_index < auctions.length, "digit correct index for array");
        _;
    }
    function showAuctionsList() public view virtual returns (Auction[] memory) {
        return auctions;
    }
    function showAuction(
        uint _index
    ) public view virtual returns (Auction memory) {
        return auctions[_index];
    }
    function setFeeSeller(
        uint[] memory _echelons,
        uint[] memory _fees
    ) external virtual onlyOwner {
        feeSeller.echelons = _echelons;
        feeSeller.fees = _fees;
    }
    function newAcutionBond(
        uint _id,
        uint _amount,
        uint _startPrice,
        uint _expired,
        uint _tolleratedDiscount
    ) external virtual nonReentrant {
        require(_amount > 0, "Set correct bond's amount");
        require(_startPrice > 0, "Set correct start price");
        require(
            _expired > (block.timestamp + minPeriodAuction),
            "Set correct expired period"
        );
        _newAcutionBond(
            msg.sender,
            _id,
            _amount,
            _startPrice,
            _expired,
            _tolleratedDiscount
        ); // todo _tolleratedDiscount
    }
    function instalmentPot(
        uint _index,
        uint _amount
    ) external virtual nonReentrant outIndex(_index) {
        _instalmentPot(msg.sender, _index, _amount);
        emit newInstalmentPot(msg.sender, _index, _amount);
    }
    function closeAuction(
        uint _index
    ) external virtual nonReentrant outIndex(_index) {
        _closeAuction(msg.sender, _index);
        emit CloseAuction(_index, block.timestamp);
    }
    function withDrawBond(
        uint _index
    ) external virtual nonReentrant outIndex(_index) {
        _withDrawBond(msg.sender, _index);
    }
    function withdrawMoney(uint _amount) external virtual nonReentrant {
        _withdrawMoney(msg.sender, _amount);
        emit WithDrawMoney(msg.sender, _amount);
    }
    // fUNZIONI PER IL DEPOSITO
    function _newAcutionBond(
        address _user,
        uint _id,
        uint _amount,
        uint _startPrice,
        uint _expired,
        uint _tolleratedDiscount
    ) internal virtual {
        _depositBond(_user, address(this), _id, _amount);
        _setAuctionData(
            _user,
            _id,
            _amount,
            _startPrice,
            _expired,
            _tolleratedDiscount
        ); //todo _tolleratedDiscount
    }
    function _depositBond(
        address _user,
        address _to,
        uint _id,
        uint _amount
    ) internal virtual {
        IERC1155(bondContract).safeTransferFrom(_user, _to, _id, _amount, "");
    }
    function _setAuctionData(
        address _owner,
        uint _id,
        uint _amount,
        uint _startPrice,
        uint _expired,
        uint _tolleratedDiscount //todo
    ) internal virtual {
        uint[] memory _penality;
        Auction memory _auction = Auction(
            _owner,
            _id,
            _amount,
            _startPrice,
            _expired,
            0,// ! qui va verificato se il controllo regge dopo
            _owner,
            true,
            _tolleratedDiscount, // todo
            _penality //todo
        );
        auctions.push(_auction);
        emit NewAuction(_owner, _id, _amount);
    }
    // todo aggiunta per controlli
    function _checkPot(
        uint _index,
        uint _pot,
        uint _amount,
        uint _tolleratedDiscount
    ) internal view  {
    if(_pot >0){
        require(
            _pot > _amount, //todo inveritito il "<" ora l'offerta al netto delle fees deve essere più piccola
            "This pot is higher than the current pot."
        );
        require(
            _amount >= _pot - calculateBasisPoints(_pot, _tolleratedDiscount),
            "This pot is lower then tolerated Discount "
        );
    }else{
        require(
            auctions[_index].startPrice > _amount, //todo inveritito il "<" ora l'offerta al netto delle fees deve essere più piccola
            "This pot is higher than the current pot."
        );
        require(
            _amount >= auctions[_index].startPrice - calculateBasisPoints(auctions[_index].startPrice, _tolleratedDiscount),
            "This pot is lower then tolerated Discount "
        );
        
    }
    
    }
    // funzioni per puntare
    function _instalmentPot(
        address _player,
        uint _index,
        uint _amount
    ) internal virtual {
        require(
            auctions[_index].expired > block.timestamp,
            "This auction is expired"
        );
        require(auctions[_index].open == true, "This auction is close");
        // todo la funzione garantisce i controlli sull'offerta più bassa e sulla tolleranza allo sconto
        _checkPot(
            _index,
            auctions[_index].pot,
            _calcPotFee(_amount),
            auctions[_index].tolleratedDiscount
        );
        require(auctions[_index].owner != _player, "Owner can't pot");
        coolDownControl(_player, _index);
        // deposito i token
        _depositErc20(_player, address(this), _amount);
        uint amountLessFee = _paidPotFee(_amount);
        lockBalance[_player] += amountLessFee;
        balanceUser[_player] += amountLessFee; //non mi convince
        // aggiorno i dati
        //prima devo sloccare i soldi al altro player
        lockBalance[auctions[_index].player] -= auctions[_index].pot;
        auctions[_index].player = _player;
        auctions[_index].pot = amountLessFee;
    }
    function _calcPotFee(uint _amount) internal view virtual returns (uint) {
        if (_amount < feeSystem.priceThreshold) {
            return _amount - feeSystem.fixedFee;
        } else {
            return
                _amount - calculateBasisPoints(_amount, feeSystem.dinamicFee);
        }
    }
    function _paidPotFee(uint _amount) internal virtual returns (uint) {
        if (_amount < feeSystem.priceThreshold) {
            contractBalance += feeSystem.fixedFee;
            emit PaidFee(_amount);
            return _amount - feeSystem.fixedFee;
        } else {
            contractBalance += calculateBasisPoints(
                _amount,
                feeSystem.dinamicFee
            );
            emit PaidFee(_amount);
            return
                _amount - calculateBasisPoints(_amount, feeSystem.dinamicFee);
        }
    }
    function calculateBasisPoints(
        uint256 amount,
        uint256 bps
    ) internal pure virtual returns (uint) {
        return (amount * bps) / 10000; // 10000 bps = 100%
    }
    function _depositErc20(
        address _from,
        address _to,
        uint _amount
    ) internal virtual {
        SafeERC20.safeTransferFrom(IERC20(money), _from, _to, _amount);
    }

    // todo Aggiungo la funzione per cambiare la forchetta di sconto

    function showAuctionPenalityes(uint _index) external view returns(uint[] memory){
        return  auctions[_index].penality;
    }
    event ChangeTolleratedDiscount(uint indexed _index, uint _newDiscount);
    function changeTolleratedDiscount(
        uint _index,
        uint _newDiscount
    ) external nonReentrant outIndex(_index) whenNotPaused {
        _changeTolleratedDiscount(msg.sender, _index, _newDiscount);
    }
    function _changeTolleratedDiscount(
        address _owner,
        uint _index,
        uint _newDiscount
    ) internal {
        require(_owner == auctions[_index].owner, "Not Owner");
        require(
            auctions[_index].expired > block.timestamp,
            "This auction is not expired"
        );
        require(auctions[_index].open == true, "This auction already close");
        require(
            auctions[_index].tolleratedDiscount < _newDiscount,
            "Dew Discount must be more  great then older Discount"
        );
        if (auctions[_index].expired - block.timestamp >= 1 days) {
            //!Scadenza superiore ad 1 giorno 5%
            auctions[_index].penality.push(500);
        } else if (
            auctions[_index].expired - block.timestamp < 1 days &&
            auctions[_index].expired - block.timestamp >= 1 hours
        ) {
            //!Scadenza tra 24h e 23h 8%
            auctions[_index].penality.push(800);
        } else {
            //! scadenza sotto 1h 10%
            auctions[_index].penality.push(1000);
        }
        auctions[_index].tolleratedDiscount = _newDiscount;
        emit ChangeTolleratedDiscount(_index, _newDiscount);
    }

    // todo Chiusura d'emergenza
    function _emergencyCloseAuction(address _owner, uint _index) internal {
        require(
            auctions[_index].expired > block.timestamp,
            "This auction is not expired"
        );
        require(_owner == auctions[_index].owner, "Not Owner");
        require(auctions[_index].open == true, "This auction already close");

        auctions[_index].open = false;
        if (auctions[_index].expired - block.timestamp >= 1 days) {
            //!Scadenza superiore ad 12h giorno 15%
            auctions[_index].penality.push(1500);
        } else {
            //!Scadenza minore 12h 20%
            auctions[_index].penality.push(2000);
        }
        _closeAuctionOperation(_index);
    }

    // funzione per chiudere l'auction alla fine del processo
    // todo divisa la funzione
    function _closeAuction(address _owner, uint _index) internal virtual {
        require(
            auctions[_index].expired < block.timestamp,
            "This auction is not expired"
        );
        require(
            _owner == auctions[_index].owner ||
                _owner == auctions[_index].player ||
                _owner == owner(), //? per ora lascio la possibilità al owner di forzare la chiusura di un asta per incassare le fees
            "Not Owner"
        );
        require(auctions[_index].open == true, "This auction already close");
        auctions[_index].open = false;
        _closeAuctionOperation(_index);
    }

    // todo divisa la funzione di close per riutilizzare parte di codice
    function _closeAuctionOperation(uint _index) internal {
        address newOwner = auctions[_index].player;
        address oldOwner = auctions[_index].owner;

        //! logica calcolo penalità
        uint pot = auctions[_index].pot;
        for (uint i = 0; i < auctions[_index].penality.length; i++) {
            pot = _paidPenalityFees(pot, auctions[_index].penality[i]);
        }
        //! ---------------

        pot = _paidSellFee(pot);

        auctions[_index].pot = 0;
        auctions[_index].owner = newOwner;

        balanceUser[newOwner] -= pot;
        lockBalance[newOwner] -= pot;

        balanceUser[oldOwner] += pot;
    }

    function _paidPenalityFees(
        uint _amount,
        uint _penality
    ) internal returns (uint) {
        uint fee = calculateBasisPoints(_amount, _penality);
        contractBalance += fee;
        return _amount - fee;
    }

    function _paidSellFee(uint _amount) internal virtual returns (uint) {
        for (uint i; i < feeSeller.echelons.length; i++) {
            if (_amount < feeSeller.echelons[i]) {
                uint fee = calculateBasisPoints(_amount, feeSeller.fees[i]);
                contractBalance += fee;
                emit PaidFee(fee);
                return _amount - fee;
            }
        }
        uint _fee = calculateBasisPoints(
            _amount,
            feeSeller.fees[feeSeller.fees.length - 1]
        );
        contractBalance += _fee;
        emit PaidFee(_fee);
        return _amount - _fee;
    }
    function _withDrawBond(address _owner, uint _index) internal virtual {
        require(_owner == auctions[_index].owner, "Not Owner");
        require(
            auctions[_index].expired < block.timestamp,
            "This auction is not expired"
        ); // penso sia da correggere
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
    function _withdrawMoney(address _user, uint _amount) internal virtual {
        require(
            _amount <= balanceUser[_user] - lockBalance[_user],
            "Free balance is low for this operation"
        );
        require(
            lockBalance[_user] <= balanceUser[_user] - _amount,
            "Incorrect Operation"
        );
        balanceUser[_user] -= _amount;
        SafeERC20.safeTransfer(IERC20(money), _user, _amount);
    }
    //Freez system
    function setCoolDown(uint _coolDown) external virtual onlyOwner {
        coolDown = _coolDown;
    }
    function coolDownControl(address _user, uint _id) internal virtual {
        require(
            lastPotTime[_user][_id] + coolDown < block.timestamp,
            "Wait for pot again"
        );
        lastPotTime[_user][_id] = block.timestamp;
    }
    function showFeesSystem() public view virtual returns (FeeSystem memory) {
        return feeSystem;
    }
    function showFeesSeller() public view virtual returns (FeeSeller memory) {
        return feeSeller;
    }
    // ? Non so se la lascero ma per ora mi serve in fase di testing
    function showBalanceFee() external view virtual returns (uint) {
        return contractBalance;
    }
    function withdrawFees() external virtual onlyOwner {
        uint amount = contractBalance;
        contractBalance = 0;
        SafeERC20.safeTransfer(IERC20(money), owner(), amount);
    }
    // Funzione per ricevere singoli trasferimenti ERC1155
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure override returns (bytes4) {
        // Logica personalizzata (se necessaria)
        return this.onERC1155Received.selector;
    }
    // Funzione per ricevere trasferimenti batch ERC1155
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure override returns (bytes4) {
        // Logica personalizzata (se necessaria)
        return this.onERC1155BatchReceived.selector;
    }
}
