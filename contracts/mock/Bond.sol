// SPDX-License-Identifier: Leluk911
/*
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TimeManagment} from "./library/TimeManagement.sol";

contract BondContract is ERC1155 {
    // Sceletro del bond , stabilisce i campi fondamentali,il controllo del bilancio lo faccio a parte e a parte si fanno i calcoli delle liquidazioni ecc ecc.
    struct Bond {
        uint id;
        address issuer;
        address tokenLoan;
        uint sizeLoan;
        uint interest;
        uint[] couponMaturity;
        //uint numberOfCoupon;
        uint expiredBond;
        address tokenCollateral;
        uint collateral;
        uint balancLoanRepay;
        string describes;
    }

    struct ConditionOfFee {
        address issuer;
        uint[3] penalityForLiquidation;
        uint score;
    }

    mapping(address => ConditionOfFee) internal conditionOfFee;
    mapping(uint => uint) internal numberOfLiquidations;

    // Mapping to store total supply for each token id
    mapping(uint256 => uint256) private _totalSupply;

    // id Incrementale del Bond, non gestibile dall'utente o dal creatore ma solo dal contratto per garantire l'integrita
    uint private bondId;
    // MApping Per associare le informazioni del bond a ogni bond
    mapping(uint => Bond) private bond;

    // Mapping per gestire il la proprieta dei coupon fra una cedola ed un altra cosi da garantire il giusto diritto alla riscossione
    mapping(uint => mapping(address => mapping(uint => uint))) couponToClaim;

    constructor() ERC1155("") {
        bondId = 0;
    }


/// FUNZIONI EXTERNAL ////////






















    function showDeatailBondForId(uint _id) public view returns (Bond memory) {
        return bond[_id];
    }
    function viewBondID() public view returns (uint) {
        return bondId;
    }
    function incementID() internal {
        bondId += 1;
    }

    // BISOGNA IMPLEMENTARE QUESTA FUNZIONE QUANDO SI APPLICANO LE PENALITÀ PER AGGIORNALE LE CONDIZIONI
    function _setScoreForUser(address _user) internal {
        if (
            conditionOfFee[_user].score == 0 ||
            (conditionOfFee[_user].score <= 1000 &&
                conditionOfFee[_user].score >= 700)
        ) {
            // nuovo utente 0 fascia Media
            uint[3] memory penalties = [uint(50), uint(100), uint(150)];
            conditionOfFee[_user] = ConditionOfFee(_user, penalties, 1000);
            // da capire bene l'entita dei numero e le varie grandezze nella logica di penalità o premialita
        }
        if (conditionOfFee[_user].score > 1000) {
            // fascia Alta
            uint[3] memory penalties = [uint(50), uint(100), uint(150)];
            conditionOfFee[_user].penalityForLiquidation = penalties;
        }
        if (
            conditionOfFee[_user].score < 700 &&
            conditionOfFee[_user].score >= 500
        ) {
            // fascia bassa
            uint[3] memory penalties = [uint(150), uint(300), uint(450)];
            conditionOfFee[_user].penalityForLiquidation = penalties;
        }
        if (conditionOfFee[_user].score < 500) {
            // fascia molto bassa
            uint[3] memory penalties = [uint(150), uint(300), uint(450)];
            conditionOfFee[_user].penalityForLiquidation = penalties;
        }
    }
    function _createNewBond(
        uint _id,
        address _issuer,
        address _tokenLoan,
        uint _sizeLoan,
        uint _interest,
        uint[] memory _couponMaturity,
        //uint _numberOfCoupon,
        uint _expiredBond,
        address _tokenCollateral,
        uint _collateral,
        uint _balancLoanRepay,
        uint _amount,
        string calldata _describes
    ) internal {
        bond[_id] = Bond(
            _id,
            _issuer,
            _tokenLoan,
            _sizeLoan,
            _interest,
            _couponMaturity,
            //_numberOfCoupon,
            _expiredBond,
            _tokenCollateral,
            _collateral,
            _balancLoanRepay,
            _describes
        );
        // per ora il recipiente dei token ERC1155 è l'emittente ma successivamente sara il contratto che si occupa della vendita
        _mint(_issuer, _id, _amount, "");
        _totalSupply[_id] += _amount; // Update the total supply for this token ID
    }
    function _depositCollateralToken(
        address _issuer,
        address _tokenCollateral,
        uint _amount //,
    ) internal {
        require(_amount > 0, "Qta token Incorect");
        SafeERC20.safeTransferFrom(
            IERC20(_tokenCollateral),
            _issuer,
            address(this),
            _amount
        );
        //bond[_id].balancLoanRepay += _amount;
    }
    function createNewBond(
        address _issuer,
        address _tokenLoan,
        uint _sizeLoan,
        uint _interest,
        uint[] memory _couponMaturity,
        //uint _numberOfCoupon,
        uint _expiredBond,
        address _tokenCollateral,
        uint _collateral,
        uint _amount,
        string calldata _describes
    ) external {
        _setScoreForUser(_issuer);
        _depositCollateralToken(_issuer, _tokenCollateral, _collateral);
        require(
            TimeManagment.checkDatalistAndExpired(
                _couponMaturity,
                _expiredBond
            ) == true,
            "Set correct data , Remember the coupon maturity must are crescent value, and the last value must are less then Expired Time"
        );
        //require () SETTERO UNA VERIFICA PER VERIFICARE SE I TOKEN DA PRESTARE SIANO SOLO QUELLI CHE STABILISCO IO.
        uint currentId = bondId;
        incementID();
        _createNewBond(
            currentId,
            _issuer,
            _tokenLoan,
            _sizeLoan,
            _interest,
            _couponMaturity,
            //_numberOfCoupon,
            _expiredBond,
            _tokenCollateral,
            _collateral,
            0,
            _amount,
            _describes
        );

        // qui va la logica di Minting che devo curare in un secondo momento:
        //_mint(Contratto di vendita Bond, currentId, _amount, "data");
    }
    function totalSupply(uint256 id) public view returns (uint256) {
        return _totalSupply[id];
    }

    // CREARE FUNZIONE DI BURNING TITOLI NON VENDUTI ALL'EMISSIONE O TITOLI RIACCQUISITI

    function _upDateCouponBuy(uint _id, address _user, uint qty) internal {
        uint time = block.timestamp;
        for (uint i = 0; i < bond[_id].couponMaturity.length; i++) {
            if (time < bond[_id].couponMaturity[i]) {
                couponToClaim[_id][_user][i] += qty;
            }
        }
    }
    function _upDateCouponSell(uint _id, address _user, uint qty) internal {
        uint time = block.timestamp;
        for (uint i = 0; i < bond[_id].couponMaturity.length; i++) {
            if (time < bond[_id].couponMaturity[i]) {
                couponToClaim[_id][_user][i] -= qty;
            }
        }
    }
    // trasferimento con logica aggiormaneto proprieta bond per maturazione cedole
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        // Chiama la funzione di trasferimento originale
        super.safeTransferFrom(from, to, id, amount, data);
        // Prima chiama la logica di aggiornamento dei coupon
        // togliamo cedole al venditore
        _upDateCouponSell(id, from, amount);
        // aggiungiamo cedole al compratore
        _upDateCouponBuy(id, to, amount);
    }

    function _depositTokenForInterest(
        uint _id,
        address _issuer,
        uint _amount
    ) internal {
        require(_amount > 0, "Qta token Incorect");
        SafeERC20.safeTransferFrom(
            IERC20(bond[_id].tokenLoan),
            _issuer,
            address(this),
            _amount
        );
        bond[_id].balancLoanRepay += _amount;
    }
    function _calculationLiquidatis() internal {}
    // NB PER DOPO
    // per la penalità calcolare in millesimi e dare a ogni cedola una percenutale di essa o una cosa delgenere

    function _parzialLiquidationCoupon(
        uint _id,
        address _user,
        uint _moltiplicator
    ) internal {
        // cedola : interesse = x : capitale : Capitale disponibile
        uint couponCanRepay = bond[_id].balancLoanRepay /
            (bond[_id].interest * _moltiplicator); // da capire come arrotondare
        uint qtaToCouponClaim = couponCanRepay * bond[_id].interest;
        bond[_id].balancLoanRepay -= couponCanRepay * bond[_id].interest;
        IERC20(bond[_id].tokenLoan).transfer(_user, qtaToCouponClaim);
        _executeLiquidationCoupon(_id, _user, _moltiplicator - couponCanRepay);
    }

    function claimCouponForUSer(
        uint _id,
        address _user,
        uint _indexCoupon
    ) external {
        _claimCoupon(_id, _user, _indexCoupon);
    }
    function _executeLiquidationCoupon(
        uint _id,
        address _user,
        uint _moltiplicator
    ) internal {
        require(
            numberOfLiquidations[_id] < 3,
            "This bond is expired or totaly liquidate"
        );
        // qui gestisco solo la liquidazione e non l'aggiornamento del registro delle cedole da pagare
        if (numberOfLiquidations[_id] == 0) {
            // prendiamo il totale del capitale, togliamo la percenutale che dobbiamo liquidare e la dividiamo per le cedole , e paghiamo quanto dobbiamo poi riduciamo il diritto a riscuotere la cedola
            _logicExecuteLiquidationCoupon(_id, 0, _moltiplicator, _user);
        }
        if (numberOfLiquidations[_id] == 1) {
            _logicExecuteLiquidationCoupon(_id, 1, _moltiplicator, _user);
        }
        if (numberOfLiquidations[_id] == 2) {
            _logicExecuteLiquidationCoupon(_id, 2, _moltiplicator, _user);
        }
        if (numberOfLiquidations[_id] == 3) {
            _logicExecuteLiquidationCoupon(_id, 2, _moltiplicator, _user);
        }
    }

    function _logicExecuteLiquidationCoupon(
        uint _id,
        uint _indexPenality,
        uint _moltiplicator,
        address _user
    ) internal {
        numberOfLiquidations[_id] += 1; // devo calibrare la logica delle penalità dando un valore ad ogni singola cedola oppure no, non lo so dipende quanto duro voglio essere con chi emette le cedole
        uint percCollateralOfLiquidation = ((bond[_id].collateral *
            conditionOfFee[bond[_id].issuer].penalityForLiquidation[
                _indexPenality
            ]) / 1000); // da verificare la storia delle percentuali
        uint percForCoupon = percCollateralOfLiquidation / _totalSupply[_id];
        bond[_id].collateral -= percForCoupon * _moltiplicator;
        IERC20(bond[_id].tokenCollateral).transfer(
            _user,
            percForCoupon * _moltiplicator
        );
    }
    function _logicExecuteLiquidationBond(
        uint _id,
        address _user,
        uint _moltiplicator
    ) internal {
        numberOfLiquidations[_id] += 1;
        uint percForCoupon = bond[_id].collateral / _totalSupply[_id];
        bond[_id].collateral -= percForCoupon * _moltiplicator;
        IERC20(bond[_id].tokenCollateral).transfer(
            _user,
            percForCoupon * _moltiplicator
        );
    }
    function _claimCoupon(uint _id, address _user, uint _indexCoupon) internal {
        uint moltiplicator = couponToClaim[_id][_user][_indexCoupon];
        couponToClaim[_id][_user][_indexCoupon] = 0;
        uint qtaToCouponClaim = moltiplicator * bond[_id].interest;

        if (qtaToCouponClaim <= bond[_id].balancLoanRepay) {
            // se riesco a pagare almeno tutte le cedole
            bond[_id].balancLoanRepay -= qtaToCouponClaim;
            IERC20(bond[_id].tokenLoan).transfer(_user, qtaToCouponClaim);
        } else if (qtaToCouponClaim > bond[_id].balancLoanRepay) {
            // se non riesco a pagare nemmeno una cedola
            _executeLiquidationCoupon(_id, _user, moltiplicator);
        } else {
            _parzialLiquidationCoupon(_id, _user, moltiplicator);
        }
    }
    function claimLoan(uint _id, uint _amount) external {
        _claimLoan(_id, msg.sender, _amount);
    }
    function _claimLoan(uint _id, address _user, uint _amount) internal {
        require(
            bond[_id].expiredBond <= block.timestamp,
            "Bond not be expirer"
        );
        // IN CASO DI LIQUIDAZIONE TOTALE
        if (bond[_id].sizeLoan * _amount <= bond[_id].balancLoanRepay) {
            _totaLiquidationForBondExpired(_id, _user, _amount);
        } else if (bond[_id].sizeLoan <= bond[_id].balancLoanRepay) {
            // qua VA SCALATO IL PUNTEGGIO , CI TORNO DOPO
            // titoli da pagare = capitale disponibile / importo del titolo
            uint capCanPay = bond[_id].balancLoanRepay / bond[_id].sizeLoan; // verificare poi che il conto sia arrotondato per difetto
            _totaLiquidationForBondExpired(_id, _user, capCanPay);
            _liquitationCollateralForBondExpired(
                _id,
                _user,
                (_amount - capCanPay)
            );
        } else {
            _liquitationCollateralForBondExpired(_id, _user, _amount);
        }
    }

    mapping(uint => uint8) internal freezCollateral;

    function _liquitationCollateralForBondExpired(
        uint _id,
        address _user,
        uint _amount
    ) internal {
        if (freezCollateral[_id] == 0) {
            freezCollateral[_id] += 1;
        }
        uint collateralToLiquidate = bond[_id].collateral / _totalSupply[_id];
        bond[_id].collateral -= collateralToLiquidate * _amount;
        _upDateCouponSell(_id, _user, _amount);
        _burn(_user, _id, _amount);
        IERC20(bond[_id].tokenLoan).transfer(
            _user,
            collateralToLiquidate * _amount
        );
    }
    function _totaLiquidationForBondExpired(
        uint _id,
        address _user,
        uint _amount
    ) internal {
        uint valueTokenTransfer = bond[_id].sizeLoan * _amount;
        bond[_id].balancLoanRepay -= bond[_id].sizeLoan * _amount;
        _upDateCouponSell(_id, _user, _amount); // il registro della proprieta per il pagamento delle cedole resta ancora
        _burn(_user, _id, _amount);
        IERC20(bond[_id].tokenLoan).transfer(_user, valueTokenTransfer);
    }

    // faccio prelevare tutto il collaterale dopo 15 gg
    // voglio pero bloccare in caso al blocco finale sia risultato inadempiente
    function _withdrawCollateral(uint _id, address _issuer) internal {
        if (freezCollateral[_id] != 0) {
            require(
                bond[_id].expiredBond + (90 * (1 days)) >= block.timestamp,
                "the collateral lock-up period has not yet expired, period has extended at 90 days for Liquidation"
            );
        } else {
            require(
                bond[_id].expiredBond + (15 * (1 days)) >= block.timestamp,
                "the collateral lock-up period has not yet expired"
            );
        }
        uint amountCollateral = bond[_id].collateral;
        bond[_id].collateral = 0;
        IERC20(bond[_id].tokenLoan).transfer(_issuer, amountCollateral);
    }
}

// DA FARE
/**
Capisco che tu voglia una visione chiara su come procedere senza appesantire troppo la mente. Ecco un riepilogo di ciò che ti manca da implementare, basato sulla logica attuale:
1. Liquidazione Totale alla Scadenza:

    Implementa la logica per gestire la liquidazione completa del bond alla sua scadenza, se le cedole non sono state interamente ripagate o se ci sono insolvenze. Questo sarà il meccanismo finale che si attiva quando il bond scade e non ci sono più cedole da pagare.

Prossimo passo: Aggiungi una funzione che esegua la liquidazione totale del collaterale rimanente se le condizioni non sono soddisfatte entro la scadenza del bond.
2. Ritiro del Collaterale alla Scadenza (se tutto è andato bene):

    Se il bond è scaduto e tutte le cedole sono state pagate correttamente, devi gestire il ritiro del collaterale da parte dell'emittente. Questa funzione deve verificare che non ci siano cedole in sospeso prima di permettere il ritiro del collaterale.

Prossimo passo: Implementa una funzione che consenta all'emittente di ritirare il collaterale, verificando che tutto sia stato saldato.
3. Gestione dei Coupon Maturati:

    Verifica che la logica per il pagamento dei coupon (cedole) sia stata completamente implementata. Hai già una buona base per gestire il diritto di riscossione delle cedole tramite il mapping couponToClaim, quindi potrebbe essere solo una questione di rifinire i dettagli.

4. Funzioni di Burn per i Titoli Non Venduti:

    Una funzione per gestire il burning dei bond non venduti o riacquisiti (come hai indicato nei commenti) è ancora da implementare. Questa può essere un'aggiunta successiva, ma è importante per mantenere un corretto bilanciamento della supply dei bond.

In sintesi:

    Liquidazione totale alla scadenza (se necessario).
    Ritiro del collaterale da parte dell'emittente alla scadenza (se tutto va bene).
    Rifinire la logica dei coupon.
    Aggiungere la funzione di burn per titoli non venduti/riacquisiti. 
    
    +

    - BISOGNA IMPLEMENTARE  LA FUNZIONE _setScoreForUSer QUANDO SI APPLICANO LE PENALITÀ PER AGGIORNALE LE CONDIZIONI
    - Test Totali 
    - Controlli di sicurezza
    - sistema di fees per la piattaforma
    - funzioni di sicurezza 
    - rendere il contratto aggiornabile
    - creare il contratto che si occupa della vendita dei titoli e un contratto che si occupa della vendita degli stessi 
    
    








    ho un idea che puo servirmi , manipolare il totalSupply ma mi imputtana un po il tutto 
    4. Sicurezza dei Fondi:

    Gestione del Collaterale: La gestione del collaterale sembra ben strutturata, ma è importante gestire attentamente la divisione tra capitale rimborsabile e collaterale liquido. La funzione _withdrawCollateral permette all'emittente di ritirare il collaterale dopo la scadenza del bond, ma dovresti considerare l'eventualità che ci siano ancora obblighi in sospeso e verificare che tutte le cedole siano state saldate prima di permettere il ritiro completo.




In sintesi, per completare il tutto dovresti:

    Implementare i controlli di sicurezza necessari per proteggere il contratto da attacchi.
    Calibrare e definire chiaramente il sistema di penalità e punteggio per gli emittenti.
    Aggiungere le funzionalità mancanti, come la funzione di burn e le interfacce utente per interagire con il contratto.
    Effettuare test approfonditi per assicurarti che il contratto funzioni come previsto e sia sicuro.
    Considerare le implicazioni legali e assicurarti di essere in conformità con le normative applicabili.
    */
