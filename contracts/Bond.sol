// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TimeManagment} from "./library/TimeManagement.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {console} from "hardhat/console.sol";

contract BondContract is ERC1155, Pausable, ReentrancyGuard, Ownable {
    using Address for address;

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
        uint amount;
    }
    // scheletro del sistema di condizioni per le Fee
    struct ConditionOfFee {
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

    // mapping per controllare se alla scadenza l'emittente è inadempiente
    mapping(uint => uint8) internal freezCollateral;

    // mapping per gestione punti
    mapping(uint => mapping(address => uint)) internal prizeScore;
    mapping(uint => mapping(address => uint)) internal prizeScoreAlreadyClaim;
    mapping(uint => mapping(address => uint)) internal claimedPercentage; // Nuovo mapping per tenere traccia delle percentuali già reclamate

    constructor(address _owner) Ownable(_owner) ERC1155("") {
        bondId = 0;
    }

    //EVENTI

    // Evento per tracciare i trasferimenti sicuri
    event SafeTransferFrom(
        address indexed from,
        address indexed to,
        uint indexed id,
        uint256 value
    );
    // Evento per tracciare i trasferimenti batch sicuri
    event SafeBatchTransferFrom(
        address indexed from,
        address indexed to,
        uint[] ids,
        uint256[] values
    );
    // Evento per la creazione di un nuovo bond
    event BondCreated(uint indexed id, address indexed issuer, uint amount);
    // Evento per il deposito del collaterale
    event CollateralDeposited(
        address indexed issuer,
        uint indexed id,
        uint amount
    );
    // Evento per il ritiro del collaterale
    event CollateralWithdrawn(
        address indexed issuer,
        uint indexed id,
        uint amount
    );
    // Evento per il deposito dei token per gli interessi
    event InterestDeposited(
        address indexed issuer,
        uint indexed id,
        uint amount
    );
    // Evento per la richiesta di pagamento di una cedola
    event CouponClaimed(address indexed user, uint indexed id, uint amount);
    // Evento per la richiesta di rimborso del prestito
    event LoanClaimed(address indexed user, uint indexed id, uint amount);
    // Evento per l'aggiornamento del punteggio
    event ScoreUpdated(address indexed issuer, uint newScore);

    //////// FUNZIONI DI SICUREZZA /////////

    modifier _onlyIssuer(uint _id) {
        require(
            msg.sender == bond[_id].issuer,
            "Only Issuer can call this function"
        );
        _;
    }

    // Solo il proprietario ancora da inserire // anche se penso che inseriro più ruoli rivestiti sempre da me , tipo 1,2 e 3 detective più famosi
    function setInPause() external onlyOwner {
        _pause();
    }

    function setUnPause() external onlyOwner {
        _unpause();
    }

    function _isValidAddress(address _addr) internal pure returns (bool) {
        return _addr != address(0);
    }

    // controllo da rafforzare
    function _thisIsERC20(address _addr) internal view returns (bool) {
        // prima verifico se l'indirizzo è un contratto
        if (_addr.code.length == 0) {
            return false;
        }
        try IERC20(_addr).totalSupply() returns (uint256) {
            return true;
        } catch {
            return false;
        }
    }

    //////////////////////////////////////////////////////////// external function

    // da verificare se il nonReentrant blocca alcune chiamate
    // trasferimento con logica aggiormaneto proprieta bond per maturazione cedole

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override whenNotPaused nonReentrant {
        require(to != address(0), "ERC1155: transfer to the zero address");
        // Chiama la funzione di trasferimento originale
        super.safeTransferFrom(from, to, id, amount, data);
        // Prima chiama la logica di aggiornamento dei coupon
        // togliamo cedole al venditore
        _upDateCouponSell(id, from, amount);
        // aggiungiamo cedole al compratore
        _upDateCouponBuy(id, to, amount);
        emit SafeTransferFrom(from, to, id, amount);
    }

    // trasferimento con logica aggiormaneto proprieta bond per maturazione cedole
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override whenNotPaused nonReentrant {
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );
        require(to != address(0), "ERC1155: transfer to the zero address");

        // Chiama la funzione di trasferimento originale
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
        // Loop per aggiornare le cedole per ogni token trasferito
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            // Aggiorna le cedole vendute per il mittente
            _upDateCouponSell(id, from, amount);

            // Aggiorna le cedole acquistate per il destinatario
            _upDateCouponBuy(id, to, amount);
            emit SafeBatchTransferFrom(from, to, ids, amounts);
        }
    }

    // MOSTRA IL NUMERO ID ATTUALE
    function viewBondID() public view returns (uint) {
        return bondId;
    }
    // MOSTRA LA TOTAL SUPPLY DI UN BOND
    function totalSupply(uint256 id) public view returns (uint256) {
        return _totalSupply[id];
    }

    // CREAZIONE NUOVI BOND   // 1 verifica fatta
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
    ) external whenNotPaused nonReentrant {
        require(_thisIsERC20(_tokenLoan), "Set correct address for Token Loan");
        require(_sizeLoan > 0, "set correct size Loan for variables");
        require(_interest > 0, "set correct Interest for variables");
        require(_collateral > 0, "set correct Collateral for variables");
        require(_amount > 0, "set correct amount for variables");

        require(
            TimeManagment.checkDatalistAndExpired(
                _couponMaturity,
                _expiredBond
            ) == true,
            "Set correct data , Remember the coupon maturity must are crescent value, and the last value must are less then Expired Time"
        );

        require(
            _expiredBond > _couponMaturity[_couponMaturity.length - 1],
            "Set corretc expired for this bond"
        );

        _setScoreForUser(_issuer);

        uint fee = _emisionBondFee(_issuer, _tokenCollateral, _collateral);

        _depositCollateralToken(_issuer, _tokenCollateral, _collateral); // 1& ????

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
            _collateral - fee,
            0,
            _amount,
            _describes
        );
        _setInitialPrizePoint(currentId, _issuer, _amount, _sizeLoan);
        //////////////////////////////////
        _upDateCouponBuy(currentId, _issuer, _amount); // QUESTO RIGO SERVE SOLO PER I TEST MA VA TOLTO
        ////////////////////////
    }

    // MOSTRA I DETTAGLI DI UN BOND
    function showDeatailBondForId(uint _id) public view returns (Bond memory) {
        return bond[_id];
    }

    //RICHIEDI IL PAGAMENTO DI UNA cedola
    function claimCouponForUSer(
        uint _id,
        //address _user,
        uint _indexCoupon
    ) external whenNotPaused nonReentrant {
        _claimCoupon(_id, msg.sender, _indexCoupon);
    }

    // Richiedi il pagamento del prestito alla scadenza della cedola
    function claimLoan(
        uint _id,
        uint _amount
    ) external whenNotPaused nonReentrant {
        _claimLoan(_id, msg.sender, _amount);
    }

    // funzione che permette all'emittente di depositare il capitale per rimborsare i prestiti

    function depositTokenForInterest(
        uint _id,
        uint _amount
    ) external whenNotPaused nonReentrant {
        _depositTokenForInterest(_id, msg.sender, _amount);
    }

    // riscossione del collaterale al termine della vita del bond // da valutare se voglio bloccare il collaterale nel caso di inadempienza o sbloccarlo dopo un po
    function withdrawCollateral(
        uint _id
    ) external whenNotPaused nonReentrant _onlyIssuer(_id) {
        _withdrawCollateral(_id, msg.sender);
    }

    // ricorda se l'emittente brucia i token bisogna aggiornare tutte queste logiche cosi che non possa sfruttare un cazzo
    function claimScorePoint(
        uint _id
    ) external _onlyIssuer(_id) whenNotPaused nonReentrant {
        require(bond[_id].expiredBond <= block.timestamp, "Bond isn't Expired");
        _claimScorePoint(_id, msg.sender);
    }

    function checkStatusPoints(
        address _iusser
    ) external view returns (ConditionOfFee memory) {
        return _checkStatusPoints(_iusser);
    }

    function _checkStatusPoints(
        address _iusser
    ) internal view returns (ConditionOfFee storage) {
        return conditionOfFee[_iusser];
    }

    // NB PER DOPO
    // per la penalità calcolare in millesimi e dare a ogni cedola una percenutale di essa o una cosa delgenere

    function incementID() internal {
        bondId += 1;
    }

    // BISOGNA IMPLEMENTARE QUESTA FUNZIONE QUANDO SI APPLICANO LE PENALITÀ PER AGGIORNALE LE CONDIZIONI
    // inoltre chi riceve il pagamento non partecipa alla liquidazione dell'intero bond, perche ha gia riscosso l'interesse
    // anche se una volta liquidata la cedola non c'è più garanzia e quindi puo liquidare tutto
    function _setScoreForUser(address _user) internal {
        if (
            conditionOfFee[_user].score == 0 ||
            (conditionOfFee[_user].score <= 1000000 &&
                conditionOfFee[_user].score >= 700000)
        ) {
            // nuovo utente 0 fascia Media
            uint[3] memory penalties = [uint(100), uint(200), uint(400)];
            conditionOfFee[_user] = ConditionOfFee(penalties, 700000);
            // da capire bene l'entita dei numero e le varie grandezze nella logica di penalità o premialita
            emit ScoreUpdated(_user, 700000); // forse c'è un bug nel evento ma sti cazzi
        }
        if (conditionOfFee[_user].score > 1000000) {
            // fascia Alta
            uint[3] memory penalties = [uint(50), uint(100), uint(200)];
            conditionOfFee[_user].penalityForLiquidation = penalties;
            emit ScoreUpdated(_user, 100000);
        }
        if (
            conditionOfFee[_user].score < 700000 &&
            conditionOfFee[_user].score >= 500000
        ) {
            // fascia bassa
            uint[3] memory penalties = [uint(200), uint(400), uint(600)];
            conditionOfFee[_user].penalityForLiquidation = penalties;
            emit ScoreUpdated(_user, 500000);
        }
        if (conditionOfFee[_user].score < 500000) {
            // fascia molto bassa
            uint[3] memory penalties = [uint(280), uint(450), uint(720)];
            conditionOfFee[_user].penalityForLiquidation = penalties;
            emit ScoreUpdated(_user, 499999);
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
            _describes,
            _amount
        );
        // per ora il recipiente dei token ERC1155 è l'emittente ma successivamente sara il contratto che si occupa della vendita
        _totalSupply[_id] += _amount;
        _mint(_issuer, _id, _amount, "");
        // Update the total supply for this token ID
        emit BondCreated(_id, _issuer, _amount);
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
        emit InterestDeposited(_issuer, _id, _amount);
    }

    function _parzialLiquidationCoupon(
        uint _id,
        address _user,
        uint _moltiplicator
    ) internal {
        // cedola : interesse = x : capitale : Capitale disponibile
        //uint couponCanRepay = bond[_id].balancLoanRepay /
        //    (bond[_id].interest * _moltiplicator); // da capire come arrotondare
        uint couponCanRepay = bond[_id].balancLoanRepay / bond[_id].interest;

        uint qtaToCouponClaim = couponCanRepay * bond[_id].interest;
        bond[_id].balancLoanRepay -= couponCanRepay * bond[_id].interest;
        SafeERC20.safeTransfer(
            IERC20(bond[_id].tokenLoan),
            _user,
            qtaToCouponClaim - _couponFee(bond[_id].tokenLoan, qtaToCouponClaim)
        );
        emit CouponClaimed(_user, _id, _moltiplicator);
        _subtractionPrizePoin(
            _id,
            bond[_id].issuer,
            ((_moltiplicator - couponCanRepay))
        );
        _executeLiquidationCoupon(_id, _user, _moltiplicator - couponCanRepay);
    }

    event LiquidationCoupon(
        address indexed user,
        uint indexed id,
        uint indexed amount
    );
    function _executeLiquidationCoupon(
        uint _id,
        address _user,
        uint _moltiplicator
    ) internal {
        require(
            numberOfLiquidations[_id] <= 4,
            "This bond is expired or totaly liquidate"
        );
        numberOfLiquidations[_id] += 1; // devo calibrare la logica delle penalità dando un valore ad ogni singola cedola oppure no, non lo so dipende quanto duro voglio essere con chi emette le cedole

        // qui gestisco solo la liquidazione e non l'aggiornamento del registro delle cedole da pagare
        if (numberOfLiquidations[_id] == 1) {
            // prendiamo il totale del capitale, togliamo la percenutale che dobbiamo liquidare e la dividiamo per le cedole , e paghiamo quanto dobbiamo poi riduciamo il diritto a riscuotere la cedola
            _logicExecuteLiquidationCoupon(_id, 0, _moltiplicator, _user);
        }
        if (numberOfLiquidations[_id] == 2) {
            _logicExecuteLiquidationCoupon(_id, 1, _moltiplicator, _user);
        }
        if (numberOfLiquidations[_id] == 3) {
            _logicExecuteLiquidationCoupon(_id, 2, _moltiplicator, _user);
        }
        if (numberOfLiquidations[_id] == 4) {
            _logicExecuteLiquidationBond(_id, _moltiplicator, _user);
        }
    }

    function _logicExecuteLiquidationCoupon(
        uint _id,
        uint _indexPenality,
        uint _moltiplicator,
        address _user
    ) internal {
        //_subtractionPrizePoin(_id, bond[_id].issuer, _moltiplicator);
        uint percCollateralOfLiquidation = ((bond[_id].collateral *
            conditionOfFee[bond[_id].issuer].penalityForLiquidation[
                _indexPenality
            ]) / 10000); // da verificare la storia delle percentuali

        uint percForCoupon = percCollateralOfLiquidation / bond[_id].amount; //_totalSupply[_id];
        uint fee = _liquidationFee(
            bond[_id].issuer,
            bond[_id].tokenCollateral,
            (percForCoupon * _moltiplicator)
        );

        bond[_id].collateral -= (percForCoupon * _moltiplicator) - fee;
        SafeERC20.safeTransfer(
            IERC20(bond[_id].tokenCollateral),
            _user,
            (percForCoupon * _moltiplicator) - fee
        );
        emit LiquidationCoupon(_user, _id, _moltiplicator);
    }

    event LiquidationBond(uint indexed id, uint amount);
    function _logicExecuteLiquidationBond(
        uint _id,
        uint _moltiplicator,
        address _user
    ) internal {
        _lostPoint(_id, bond[_id].issuer);
        numberOfLiquidations[_id] += 1;
        uint percForCoupon = bond[_id].collateral / bond[_id].amount;
        bond[_id].collateral -= percForCoupon * _moltiplicator;
        SafeERC20.safeTransfer(
            IERC20(bond[_id].tokenCollateral),
            _user,
            percForCoupon * _moltiplicator
        );
        emit LiquidationBond(_id, _moltiplicator);
    }

    // BUG MORTALE!!!! SE IO NON RIESCO A PAGARE UNA CEDOLA E QUALCUNO LIQUIDA LA STESSA CEDOLA L'EMITTENTE SI BECCA LA SECONDA LIQUIDAZIONE COME TASSO
    function _claimCoupon(uint _id, address _user, uint _indexCoupon) internal {
        uint moltiplicator = couponToClaim[_id][_user][_indexCoupon];
        couponToClaim[_id][_user][_indexCoupon] = 0;
        uint qtaToCouponClaim = moltiplicator * bond[_id].interest;
        if (qtaToCouponClaim <= bond[_id].balancLoanRepay) {
            // se riesco a pagare almeno tutte le cedole
            bond[_id].balancLoanRepay -= qtaToCouponClaim;
            SafeERC20.safeTransfer(
                IERC20(bond[_id].tokenLoan),
                _user,
                qtaToCouponClaim -
                    _couponFee(bond[_id].tokenLoan, qtaToCouponClaim)
            );
            emit CouponClaimed(_user, _id, qtaToCouponClaim);
        } else if (
            qtaToCouponClaim > bond[_id].balancLoanRepay &&
            bond[_id].interest > bond[_id].balancLoanRepay
        ) {
            // se non riesco a pagare nemmeno una cedola
            _subtractionPrizePoin(_id, bond[_id].issuer, ((moltiplicator)));
            _executeLiquidationCoupon(_id, _user, moltiplicator);
            emit CouponClaimed(_user, _id, 0);
        } else if (
            qtaToCouponClaim > bond[_id].balancLoanRepay &&
            bond[_id].interest <= bond[_id].balancLoanRepay
        ) {
            // lo scalo dei punti qui va direttamente nella funzione sottostante se no diventa un casino
            _parzialLiquidationCoupon(_id, _user, moltiplicator);
        }
    }

    function _claimLoan(uint _id, address _user, uint _amount) internal {
        require(
            bond[_id].expiredBond <= block.timestamp,
            "Bond not be expirer"
        );
        // IN CASO DI LIQUIDAZIONE TOTALE
        _totalSupply[_id] -= _amount; // aggiunta per vedere se va bene
        if (bond[_id].sizeLoan * _amount <= bond[_id].balancLoanRepay) {
            _totaLiquidationForBondExpired(_id, _user, _amount);
        } else if (bond[_id].sizeLoan <= bond[_id].balancLoanRepay) {
            // titoli da pagare = capitale disponibile / importo del titolo
            uint capCanPay = bond[_id].balancLoanRepay / bond[_id].sizeLoan; // verificare poi che il conto sia arrotondato per difetto
            _subtractionPrizePoin(
                _id,
                bond[_id].issuer,
                ((_amount - capCanPay))
            );
            _totaLiquidationForBondExpired(_id, _user, capCanPay);
            _liquitationCollateralForBondExpired(
                _id,
                _user,
                (_amount - capCanPay)
            );
        } else {
            _subtractionPrizePoin(_id, bond[_id].issuer, (_amount));
            _liquitationCollateralForBondExpired(_id, _user, _amount);
        }
    }

    event LiquitationCollateralBondExpired(
        address indexed user,
        uint indexed id,
        uint amount
    );
    function _liquitationCollateralForBondExpired(
        uint _id,
        address _user,
        uint _amount
    ) internal {
        if (freezCollateral[_id] == 0) {
            freezCollateral[_id] += 1;
        }
        uint collateralToLiquidate = bond[_id].collateral / bond[_id].amount;
        uint fee = _liquidationFee(
            bond[_id].issuer,
            bond[_id].tokenLoan,
            (collateralToLiquidate * _amount)
        );
        bond[_id].collateral -= (collateralToLiquidate * _amount) + fee;
        _upDateCouponSell(_id, _user, _amount);
        _burn(_user, _id, _amount);
        SafeERC20.safeTransfer(
            IERC20(bond[_id].tokenCollateral),
            _user,
            (collateralToLiquidate * _amount) - fee
        );
        emit LiquitationCollateralBondExpired(_user, _id, _amount);
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
        IERC20(bond[_id].tokenLoan).transfer(
            _user,
            valueTokenTransfer -
                _liquidationFee(
                    bond[_id].issuer,
                    bond[_id].tokenLoan,
                    valueTokenTransfer
                )
        );
        emit LoanClaimed(_user, _id, _amount);
    }

    // faccio prelevare tutto il collaterale dopo 15 gg
    // voglio pero bloccare in caso al blocco finale sia risultato inadempiente
    function _withdrawCollateral(uint _id, address _issuer) internal {
        if (freezCollateral[_id] != 0) {
            require(
                bond[_id].expiredBond + (90 * (1 days)) <= block.timestamp,
                "the collateral lock-up period has not yet expired, period has extended at 90 days for Liquidation"
            );
        } else {
            require(
                bond[_id].expiredBond + (15 * (1 days)) <= block.timestamp,
                "the collateral lock-up period has not yet expired"
            );
        }
        uint amountCollateral = bond[_id].collateral;
        //console.log("Collaterale da ritirare -> ",amountCollateral);
        //console.log("bilancio fee -> ",balanceContractFeesForToken[bond[_id].tokenCollateral]);

        bond[_id].collateral = 0;
        //console.log(amountCollateral);
        //uint balance = IERC20(bond[_id].tokenCollateral).balanceOf(bond[_id].issuer);
        //console.log(balance);
        SafeERC20.safeTransfer(
            IERC20(bond[_id].tokenCollateral),
            _issuer,
            amountCollateral
        );
        emit CollateralWithdrawn(_issuer, _id, amountCollateral);
    }

    // LOGICA SCORE POINT

    function _setInitialPrizePoint(
        uint _id,
        address _issuer,
        uint _amount,
        uint _sizeLoan
    ) internal {
        if (
            _sizeLoan >= 50000000000000000000 &&
            _sizeLoan < 100000000000000000000
        ) {
            prizeScore[_id][_issuer] = _amount * 5;
        }
        if (
            _sizeLoan >= 100000000000000000000 &&
            _sizeLoan < 500000000000000000000
        ) {
            prizeScore[_id][_issuer] = _amount * 10;
        }
        if (
            _sizeLoan >= 1000000000000000000000 &&
            _sizeLoan < 5000000000000000000000
        ) {
            prizeScore[_id][_issuer] = _amount * 20;
        }
        if (
            _sizeLoan >= 5000000000000000000000 &&
            _sizeLoan < 10000000000000000000000
        ) {
            prizeScore[_id][_issuer] = _amount * 30;
        }
        if (
            _sizeLoan >= 10000000000000000000000 &&
            _sizeLoan < 100000000000000000000000
        ) {
            prizeScore[_id][_issuer] = _amount * 50; // forse gia al limite
        }
        if (_sizeLoan >= 100000000000000000000000) {
            prizeScore[_id][_issuer] = _amount * 70; // un po inverosimile forse
        }
        //console.log("Quanti punti premio da ricevere -> ",prizeScore[_id][_issuer]);
    }
    function _subtractionPrizePoin(
        uint _id,
        address _issuer,
        uint _amount
    ) internal {
        if (
            bond[_id].sizeLoan >= 50000000000000000000 &&
            bond[_id].sizeLoan < 100000000000000000000
        ) {
            _chekPointIsnZeri(_id, _issuer, _amount, 2);
        }
        if (
            bond[_id].sizeLoan >= 100000000000000000000 &&
            bond[_id].sizeLoan < 500000000000000000000
        ) {
            _chekPointIsnZeri(_id, _issuer, _amount, 5);
        }
        if (
            bond[_id].sizeLoan >= 1000000000000000000000 &&
            bond[_id].sizeLoan < 5000000000000000000000
        ) {
            _chekPointIsnZeri(_id, _issuer, _amount, 10);
        }
        if (
            bond[_id].sizeLoan >= 5000000000000000000000 &&
            bond[_id].sizeLoan < 10000000000000000000000
        ) {
            _chekPointIsnZeri(_id, _issuer, _amount, 15);
        }
        if (
            bond[_id].sizeLoan >= 10000000000000000000000 &&
            bond[_id].sizeLoan < 100000000000000000000000
        ) {
            _chekPointIsnZeri(_id, _issuer, _amount, 25);
        }
        if (bond[_id].sizeLoan < 100000000000000000000000) {
            _chekPointIsnZeri(_id, _issuer, _amount, 35);
        }
    }
    function _chekPointIsnZeri(
        uint _id,
        address _issuer,
        uint _amount,
        uint _points
    ) internal {
        if (prizeScore[_id][_issuer] >= _amount * _points) {
            prizeScore[_id][_issuer] -= _amount * _points;
        } else {
            prizeScore[_id][_issuer] = 0;
        }
    }
    function _lostPoint(uint _id, address _issuer) internal {
        prizeScore[_id][_issuer] = 0;
    }
    // fatta da chatGPT quindi da verificare più volte
    function _claimScorePoint(uint _id, address _issuer) internal {
        // Controllo se l'emittente ha già reclamato il punteggio massimo
        require(prizeScore[_id][_issuer] > 0, "No points left to claim");

        uint totalPoints = prizeScore[_id][_issuer] +
            prizeScoreAlreadyClaim[_id][_issuer];
        // Se la supply è inferiore al 10%, emittente può reclamare tutto il punteggio
        if (_totalSupply[_id] <= bond[_id].amount / 10) {
            uint score = prizeScore[_id][_issuer];
            prizeScoreAlreadyClaim[_id][_issuer] += score;
            prizeScore[_id][_issuer] = 0; // Azzeriamo i punti rimanenti
            conditionOfFee[_issuer].score += score;
            claimedPercentage[_id][_issuer] = 100; // Segniamo che il 100% dei punti è stato reclamato
            emit ScoreUpdated(_issuer, score);
        }
        // Se la supply è inferiore al 25%, emittente può reclamare il 75% del punteggio rimanente
        else if (
            _totalSupply[_id] <= bond[_id].amount / 4 &&
            claimedPercentage[_id][_issuer] < 75
        ) {
            uint claimablePercentage = 75 - claimedPercentage[_id][_issuer]; // Percentuale rimanente che può essere reclamata
            uint score = (totalPoints * claimablePercentage) / 100;
            prizeScoreAlreadyClaim[_id][_issuer] += score;
            prizeScore[_id][_issuer] -= score;
            conditionOfFee[_issuer].score += score;
            claimedPercentage[_id][_issuer] += claimablePercentage; // Aggiorniamo la percentuale reclamata
            emit ScoreUpdated(_issuer, score);
        }
        // Se la supply è inferiore al 50%, emittente può reclamare il 50% del punteggio rimanente
        else if (
            _totalSupply[_id] <= bond[_id].amount / 2 &&
            claimedPercentage[_id][_issuer] < 50
        ) {
            uint claimablePercentage = 50 - claimedPercentage[_id][_issuer]; // Percentuale rimanente che può essere reclamata
            uint score = (totalPoints * claimablePercentage) / 100;
            prizeScoreAlreadyClaim[_id][_issuer] += score;
            prizeScore[_id][_issuer] -= score;
            conditionOfFee[_issuer].score += score;
            claimedPercentage[_id][_issuer] += claimablePercentage; // Aggiorniamo la percentuale reclamata
            emit ScoreUpdated(_issuer, score);
        }
    }

    // LOGICA FEES

    // VANNO TUTTE APPLICATE AI VARI CASI ANCORA

    mapping(address => uint) internal balanceContractFeesForToken;

    // va tolto il collaterale dal totale caricato a bilancio
    function _emisionBondFee(
        address _iusser,
        address _tokenAddress,
        uint _amountCollateral
    ) internal returns (uint) {
        if (conditionOfFee[_iusser].score > 1000000) {
            // top affidabilità
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    5
                ); // le fee in millesimi 0.5%
        }
        if (
            conditionOfFee[_iusser].score > 700000 &&
            conditionOfFee[_iusser].score <= 1000000
        ) {
            // top affidabilità
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    15
                ); // le fee in millesimi 1.5%
        }
        if (
            conditionOfFee[_iusser].score > 500000 &&
            conditionOfFee[_iusser].score <= 700000
        ) {
            // top affidabilità
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    30
                ); // le fee in millesimi 3%
        }
        if (conditionOfFee[_iusser].score <= 500000) {
            // top affidabilità
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    50
                ); // le fee in millesimi 5%
        }
        return 0;
    }

    event PaidFeeAtContract(address indexed token, uint indexed amount);
    function _updateBalanceContractForEmissionNewBond(
        address _tokenAddress,
        uint _amountCollateral,
        uint _fee
    ) internal returns (uint) {
        //SafeERC20(IERC20(_tokenAddress).transferFrom(_iusser, address(this), (_amountCollateral *_fee)/1000)); // 1000 - 0.5
        balanceContractFeesForToken[_tokenAddress] +=
            (_amountCollateral * _fee) /
            1000;
        emit PaidFeeAtContract(_tokenAddress, _amountCollateral * _fee);
        return (_amountCollateral * _fee) / 1000;
    }

    function _liquidationFee(
        address _iusser,
        address _tokenAddress,
        uint _amountCollateral
    ) internal returns (uint) {
        if (conditionOfFee[_iusser].score > 1000000) {
            // top affidabilità
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    5
                ); // le fee in millesimi 0.5%
        }
        if (
            conditionOfFee[_iusser].score > 700000 &&
            conditionOfFee[_iusser].score <= 1000000
        ) {
            // top affidabilità
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    1
                ); // le fee in millesimi 1.5%
        }
        if (
            conditionOfFee[_iusser].score > 500000 &&
            conditionOfFee[_iusser].score <= 700000
        ) {
            // top affidabilità
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    2
                ); // le fee in millesimi 3%
        }
        if (conditionOfFee[_iusser].score <= 500000) {
            // top affidabilità
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    4
                ); // le fee in millesimi 5%
        }
        return 0;
    }

    function _couponFee(
        address _tokenAddress,
        uint _amount
    ) internal returns (uint) {
        // fee fissa a 0.5%
        return _upDateBalanceUserFees(_tokenAddress, _amount, 50); //in millesimi
    }
    function _expiredFee(
        address _tokenAddress,
        uint _amount
    ) internal returns (uint) {
        // fee fissa a 0.1%
        return _upDateBalanceUserFees(_tokenAddress, _amount, 10); //in millesimi
    }

    function _upDateBalanceUserFees(
        address _tokenAddress,
        uint _amount,
        uint _fee
    ) internal returns (uint) {
        // fee fissa a 0.5%
        balanceContractFeesForToken[_tokenAddress] += (_amount * _fee) / 1000; // Il calcolo lo faccio fuori sfalcandolo prima dalla quantità da inviare al titolare del bond
        return (_amount * 5) / 1000;
    }

    event WitrawBalanceContracr(address indexed token, uint indexed amount);
    function withdrawContractBalance(address _tokenAddress) external onlyOwner {
        uint balance = balanceContractFeesForToken[_tokenAddress];
        balanceContractFeesForToken[_tokenAddress] = 0;
        SafeERC20.safeTransfer(IERC20(_tokenAddress), owner(), balance);
        emit WitrawBalanceContracr(_tokenAddress, balance);
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
