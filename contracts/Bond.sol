// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.24;

/**
 * @dev Imports for libraries and base contracts:
 * - ERC1155: standard implementation for multi-asset tokens (various token IDs).
 * - IERC20: standard interface for ERC20 tokens.
 * - SafeERC20: safe methods for ERC20 transfers (handles 'false' returns and reverts).
 * - Pausable: allows pausing and unpausing the contract (e.g., in emergencies).
 * - ReentrancyGuard: prevents reentrancy attacks (recursive calls on sensitive functions).
 * - Ownable: defines an 'owner' role with special privileges (e.g., pause/unpause, fee updates).
 * - TimeManagement: custom library for date and time operations (e.g., coupon maturities).
 */
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TimeManagment} from "./library/TimeManagement.sol";
import {BondStorage} from "./BondStorage.sol";

//import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
//import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
//import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
//import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
//import {ERC1155Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';

import {console} from "hardhat/console.sol";

contract BondContract is
    BondStorage,
    ERC1155,
    Pausable,
    ReentrancyGuard,
    Ownable
{
    /**
     * @dev Emitted when a single safe transfer occurs (part of the custom logic).
     */
    event SafeTransferFrom(
        address indexed from,
        address indexed to,
        uint indexed id,
        uint256 value
    );

    /**
     * @dev Emitted when a safe batch transfer occurs.
     */
    event SafeBatchTransferFrom(
        address indexed from,
        address indexed to,
        uint[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted upon creating a new bond (BondCreated).
     */
    event BondCreated(uint indexed id, address indexed issuer, uint amount);

    /**
     * @dev Emitted when collateral is deposited for a bond.
     */
    event CollateralDeposited(
        address indexed issuer,
        uint indexed id,
        uint amount
    );

    /**
     * @dev Emitted when collateral is withdrawn for a bond.
     */
    event CollateralWithdrawn(
        address indexed issuer,
        uint indexed id,
        uint amount
    );

    /**
     * @dev Emitted when interest tokens are deposited to cover bond coupons.
     */
    event InterestDeposited(
        address indexed issuer,
        uint indexed id,
        uint amount
    );

    /**
     * @dev Emitted when a user claims an interest coupon for a bond.
     */
    event CouponClaimed(address indexed user, uint indexed id, uint amount);

    /**
     * @dev Emitted when a user claims the loan amount (principal) at bond expiry.
     */
    event LoanClaimed(address indexed user, uint indexed id, uint amount);

    /**
     * @dev Emitted when the issuer's score is updated, typically after certain events.
     */
    event ScoreUpdated(address indexed issuer, uint newScore);

    /**
     * @dev Event emitted when a coupon liquidation process occurs.
     * @param user   The address of the bond holder initiating the liquidation.
     * @param id     The bond ID.
     * @param amount The amount of coupons (multiplier) involved in the liquidation.
     */
    event LiquidationCoupon(
        address indexed user,
        uint indexed id,
        uint indexed amount
    );

    /**
     * @dev Event emitted when the bond itself (collateral) is fully or further liquidated.
     * @param id     The bond ID that is being liquidated.
     * @param amount The number of tokens or multiplier used to compute the liquidation portion.
     */
    event LiquidationBond(uint indexed id, uint amount);

    /**
     * @dev Event emitted when collateral is liquidated at bond expiry.
     * @param user   The user receiving the liquidated collateral.
     * @param id     The bond ID being liquidated.
     * @param amount The quantity of bond tokens being redeemed against collateral.
     */
    event LiquitationCollateralBondExpired(
        address indexed user,
        uint indexed id,
        uint amount
    );

    /**
     * @dev Emitted when a fee is credited to the contract for a specific token.
     * @param token  The address of the token for which the fee is collected.
     * @param amount The raw calculation of `(_amountCollateral * _fee)`,
     *               before dividing by 1000. This represents the fee in “millis” form.
     */
    event PaidFeeAtContract(address indexed token, uint indexed amount);

    /**
     * @dev Emitted when the contract owner withdraws accumulated fees for a specific token.
     * @param token  The ERC20 token address from which the balance is withdrawn.
     * @param amount The amount of tokens withdrawn.
     */
    event WitrawBalanceContracr(address indexed token, uint indexed amount);

    /**
     * @dev Restricts access to functions so that only the bond's issuer can call them.
     *      Ensures that `msg.sender` matches the 'issuer' field in the Bond struct.
    */
    modifier _onlyIssuer(uint _id) {
        require(
            msg.sender == bond[_id].issuer,
            "Only Issuer can call this function"
        );
        _;
    }

    /**
     * @dev Constructor sets initial state:
     * - Assigns the contract owner using `Ownable(_owner)`.
     * - Initializes the ERC1155 base URI as an empty string (can be overridden later).
     * - Sets the initial bond counter (`bondId`) to 0.
     */

    constructor(address _owner) Ownable(_owner) ERC1155("") {
        bondId = 0;
        MAX_COUPONS = 6;
    }

    /*

function initialize(address _owner) public initializer {
        __Ownable_init();
        transferOwnership(_owner);
        bondId = 0;
        MAX_COUPONS = 6; 
    }
*/

    /**
     * @dev Allows the contract owner to pause the contract (via OpenZeppelin's Pausable).
     *      When paused, certain functions or transfers may be restricted.
     */
    function setInPause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Allows the contract owner to unpause the contract.
     *      Restores normal operation after a pause.
     */
    function setUnPause() external onlyOwner {
        _unpause();
    }


    /**
     * @dev Updates the maximum number of coupons allowed for bonds.
     *      This function can only be called by the owner of the contract.
     * @param _MAX_COUPONS The new maximum number of coupons to be set.
     */
    function setMAX_COUPONS(uint _MAX_COUPONS) external onlyOwner {
        MAX_COUPONS = _MAX_COUPONS;
    }

    /**
     * @dev Updates the fixed transfer fee (in WETH). Only the owner can modify.
     * @param _fee The new fee value.
     */
    function setTransfertFee(uint _fee) external onlyOwner {
        transfertFee = _fee;
    }

    /**
     * @dev Toggles or sets the ecosystem status for a given address.
     *      If `_state` is true, the address is considered part of the ecosystem (exempt from certain fees).
     * @param _contract The address to modify.
     * @param _state Boolean indicating whether it's part of the ecosystem or not.
     */
    function setEcosistemAddress(
        address _contract,
        bool _state
    ) external onlyOwner {
        ecosistemAddress[_contract] = _state;
    }

    /**
     * @dev Sets the launcher contract address where the first bond transfer should be directed.
     *      Must not be the zero address.
     * @param _contract The address of the launcher contract.
     */
    function setlauncherContract(address _contract) external onlyOwner {
        require(_contract != address(0), "set correct Address");
        launcherContract = _contract;
    }

    /**
     * @dev Sets the address of the WETH token used for fee payments.
     *      Must not be the zero address.
     * @param _address The WETH contract address.
     */
    function setWETHaddress(address _address) external onlyOwner {
        require(_address != address(0), "set correct Address");
        WHET = _address;
    }

    /**
     * @dev Sets the coupon fee used in the system.
     *      This function can only be called by the owner of the contract.
     * @param _fee The new coupon fee to be set. Must be greater than zero.
     * @notice Ensures that the fee is set to a valid value to prevent incorrect configurations.
     */
    function setCOUPON_FEE(uint _fee) external onlyOwner {
        require(_fee > 0, "Set a valid fee");
        COUPON_FEE = _fee;
    }

    /**
     * @dev Sets the address of the treasury.
     *      Must not be the zero address.
     * @param _address The treasury contract address.
     */
    function setTreasuryAddress(address _address) external onlyOwner {
        require(_address != address(0), "set correct Address");
        treasury = _address;
    }

    /**
     * @dev Updates a specific element in the LIQUIDATION_FEE array.
     * @param _index The index of the element to update (0-3).
     * @param _value The new value to set at the specified index.
     * @notice This function can only be called by the owner of the contract.
     * @notice Reverts if the index is out of bounds or the value is invalid.
     */
    function updateLiquidationFee(uint _index, uint _value) external onlyOwner {
        require(_index < LIQUIDATION_FEE.length, "Invalid index");
        require(_value > 0, "Value must be greater than 0");
        LIQUIDATION_FEE[_index] = _value;
    }

    /**
     * @dev Updates the entire LIQUIDATION_FEE array.
     * @param _newFees The new array of liquidation fees to set.
     * @notice This function can only be called by the owner of the contract.
     * @notice The provided array must have exactly 4 elements.
     */
    function updateLiquidationFees(uint[4] memory _newFees) external onlyOwner {
        LIQUIDATION_FEE = _newFees;
    }

    /**
     * @dev Updates the penalty values for the specified category.
     *      Only the contract owner can update these values.
     * @param category The category to update:
     *        1 = mediumPenalties, 2 = highPenalties, 3 = lowPenalties, 4 = veryLowPenalties.
     * @param newPenalties An array of 3 new penalty values.
     * @notice The array `newPenalties` must contain exactly 3 values in strictly increasing order.
     */
    function updatePenalties(
        uint category,
        uint[3] memory newPenalties
    ) external onlyOwner {
        require(category >= 1 && category <= 4, "Invalid category");
        require(
            newPenalties.length == 3,
            "Array must contain exactly 3 values"
        );
        require(
            newPenalties[0] < newPenalties[1] &&
                newPenalties[1] < newPenalties[2],
            "Values must be in strictly increasing order"
        );

        if (category == 1) {
            mediumPenalties = newPenalties;
        } else if (category == 2) {
            highPenalties = newPenalties;
        } else if (category == 3) {
            lowPenalties = newPenalties;
        } else if (category == 4) {
            veryLowPenalties = newPenalties;
        }
    }

    /**
     * @dev Allows the contract owner to withdraw the entire fee balance of a specific token.
     *      Resets the internal fee balance for that token to zero and transfers it to the owner.
     *
     * @param _tokenAddress The ERC20 token being withdrawn.
     */
    function withdrawContractBalance(address _tokenAddress) external onlyOwner {
        uint balance = balanceContractFeesForToken[_tokenAddress];
        balanceContractFeesForToken[_tokenAddress] = 0;
        SafeERC20.safeTransfer(IERC20(_tokenAddress), treasury, balance);
        emit WitrawBalanceContracr(_tokenAddress, balance);
    }

    //? EXTERNAL USER FUNCTION

    /**
     * @dev Overridden safeTransferFrom that enforces:
     *      1. "firstTransfer" logic: if tokens move from `launcherContract` back to the bond issuer,
     *         the next transfer must also go to the `launcherContract`.
     *      2. A transfer fee in WETH if both `from` and `to` are outside the ecosystem.
     *
     * Steps:
     *  - If `from == launcherContract && to == bond[id].issuer`, set `firstTransfer[id] = true`.
     *    Otherwise, set it to false.
     *  - If `firstTransfer[id]` is true, require `to == launcherContract`.
     *  - If both addresses are non-ecosystem, charge `transfertFee` in WETH from `from`.
     *  - Update the coupon ownership logic (`_upDateCouponSell` / `_upDateCouponBuy`).
     *  - Perform the parent `safeTransferFrom` and emit a custom event.
     *
     * @param from  The address sending (transferring) the bond tokens.
     * @param to    The address receiving the bond tokens.
     * @param id    The unique identifier (token ID) for the bond type being transferred.
     * @param amount The quantity of tokens of that bond ID to transfer.
     * @param data  Additional data, forwarded to the parent ERC1155 contract call.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override whenNotPaused nonReentrant {
        require(to != address(0), "ERC1155: transfer to the zero address");

       // If this bond is flagged for the next transfer to go to launcher, enforce that
        if (firstTransfer[id]) {
            require(to == launcherContract, "1st tx must send Launcher");
        }


        // If tokens move from the launcher back to the issuer, force the next transfer to go to the launcher
        if (from == launcherContract && to == bond[id].issuer) {
            firstTransfer[id] = true;
        } else {
            firstTransfer[id] = false;
        }

     

        // Charge a transfer fee if both from/to are outside the ecosystem
        if (
            !ecosistemAddress[from] &&
            !ecosistemAddress[to] &&
            to != launcherContract &&
            from != launcherContract
        ) {
            SafeERC20.safeTransferFrom(
                IERC20(WHET),
                from,
                address(this),
                transfertFee
            );
            balanceContractFeesForToken[WHET] += transfertFee;
        }

        // Update coupon ownership (removing from the seller, granting to the buyer)
        _upDateCouponSell(id, from, amount);
        _upDateCouponBuy(id, to, amount);

        // Execute the actual ERC1155 transfer
        super.safeTransferFrom(from, to, id, amount, data);

        // Emit a custom event
        emit SafeTransferFrom(from, to, id, amount);
    }

    /**
     * @dev Overridden safeBatchTransferFrom that:
     *      1. Applies a WETH fee if both `from` and `to` are outside the ecosystem.
     *      2. Checks and updates the `firstTransfer` logic for each token ID in the batch.
     *      3. Updates coupon ownership for each bond ID transferred.
     *
     * @param from   The address sending (transferring) the bond tokens.
     * @param to     The address receiving the bond tokens.
     * @param ids    An array of token IDs to transfer.
     * @param amounts An array of respective quantities for each token ID in `ids`.
     * @param data   Additional data passed through to the parent ERC1155 function call.
     */
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

        // If both addresses are outside the ecosystem, charge a fee for each bond ID
        if (!ecosistemAddress[from] && !ecosistemAddress[to]) {
            SafeERC20.safeTransferFrom(
                IERC20(WHET),
                from,
                address(this),
                transfertFee * ids.length
            );
            balanceContractFeesForToken[WHET] += transfertFee * ids.length;
        }

        // Update coupon ownership for each ID, and enforce 'firstTransfer' rules
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            // If this bond ID is flagged for firstTransfer, it must go to the launcher
            if (firstTransfer[id]) {
                require(to == launcherContract, "1st tx must send Launcher");
            }

            // If transferring from the launcher back to issuer, re-enable firstTransfer for next time
            if (from == launcherContract && to == bond[id].issuer) {
                firstTransfer[id] = true;
            } else {
                firstTransfer[id] = false;
            }

            // Update coupon ownership (subtract from `from`, add to `to`)
            _upDateCouponSell(id, from, amount);
            _upDateCouponBuy(id, to, amount);
        }

        // Execute the actual ERC1155 batch transfer
        super.safeBatchTransferFrom(from, to, ids, amounts, data);

        // Emit a custom event for batch transfers
        emit SafeBatchTransferFrom(from, to, ids, amounts);
    }

    /**
     * @dev Creates a new bond, verifying key parameters and locking collateral.
     *      1) Checks the validity of `_tokenLoan` (must look like an ERC20).
     *      2) Ensures that loan, interest, collateral, and amount are > 0.
     *      3) Validates coupon maturities and final expiry using the TimeManagment library.
     *      4) Updates the issuer's score and takes an issuance fee (`_emisionBondFee`).
     *      5) Deposits collateral and records the new bond in storage.
     *
     * Steps:
     *  - Check that `_tokenLoan` is a valid ERC20, and all necessary fields (`_sizeLoan`, `_interest`, etc.) are > 0.
     *  - Verify the coupon maturity schedule (`_couponMaturity`) is strictly increasing and ends before `_expiredBond`.
     *  - Update the issuer’s score and calculate an issuance fee.
     *  - Transfer `_collateral` from `_issuer` to the contract, subtracting the fee from the final bond collateral.
     *  - Increment bondId, then store bond details by calling `_createNewBond`.
     *  - Optionally, `_setInitialPrizePoint` seeds reward points for the issuer.
     *  - `_upDateCouponBuy` is called here for testing (may be removed or adjusted).
     *
     * @param _issuer           The address issuing the bond.
     * @param _tokenLoan        The ERC20 token used to represent the bond's principal.
     * @param _sizeLoan         The total amount the issuer wants to borrow.
     * @param _interest         The interest (per coupon) or rate to be paid.
     * @param _couponMaturity   Array of timestamps representing the coupon due dates.
     * @param _expiredBond      The timestamp after which the bond is fully matured.
     * @param _tokenCollateral  The ERC20 token used as collateral.
     * @param _collateral       The amount of collateral pledged.
     * @param _amount           The total supply (quantity) of the bond to mint (ERC1155).
     * @param _describes        A descriptive string explaining the bond.
     */
    function createNewBond(
        address _issuer,
        address _tokenLoan,
        uint _sizeLoan,
        uint _interest,
        uint[] memory _couponMaturity,
        uint _expiredBond,
        address _tokenCollateral,
        uint _collateral,
        uint _amount,
        string calldata _describes
    ) external whenNotPaused nonReentrant  {
        require(_thisIsERC20(_tokenLoan), "Set correct address for Token Loan");
        require(_sizeLoan > 0, "set correct size Loan for variables");
        require(_interest > 0, "set correct Interest for variables");
        require(_collateral > 0, "set correct Collateral for variables");
        require(_amount > 0, "set correct amount for variables");
        require(_couponMaturity.length <= MAX_COUPONS, "Too many coupons");

        // Validate coupon schedule and final expiry
        require(
            TimeManagment.checkDatalistAndExpired(
                _couponMaturity,
                _expiredBond
            ),
            "Set correct data, coupon maturity must be ascending; last < expiredBond"
        );
        require(
            _expiredBond > _couponMaturity[_couponMaturity.length - 1],
            "Set correct expiry for this bond"
        );

        // Update the issuer's score and charge an issuance fee
        _setScoreForUser(_issuer);
        uint fee = _emisionBondFee(_issuer, _tokenCollateral, _collateral);

        // Transfer collateral from issuer to this contract
        _depositCollateralToken(_issuer, _tokenCollateral, _collateral);

        // Prepare a unique bond ID
        uint currentId = bondId;
        incementID();

        // Store and initialize the new bond
        _createNewBond(
            currentId,
            _issuer,
            _tokenLoan,
            _sizeLoan,
            _interest,
            _couponMaturity,
            _expiredBond,
            _tokenCollateral,
            _collateral - fee, // subtract the issuance fee
            0, // balancLoanRepay starts at 0
            _amount,
            _describes
        );

        // Assign initial prize score (if applicable)
        _setInitialPrizePoint(currentId, _issuer, _amount, _sizeLoan);

        // For testing/demo, updates coupons as if they're already held by the issuer
        _upDateCouponBuy(currentId, _issuer, _amount); // This line may be removed later
    }

    /**
     * @dev Allows a user to claim the coupon (interest payment) for a specific bond at a given coupon index.
     *      Calls the internal function `_claimCoupon`, forwarding `msg.sender` as the claimant.
     *
     * @param _id           The ID of the bond for which the coupon is claimed.
     * @param _indexCoupon  The index in the bond’s `couponMaturity` array identifying which coupon is claimed.
     */
    function claimCouponForUSer(
        uint _id,
        uint _indexCoupon
    ) external whenNotPaused nonReentrant {
        _claimCoupon(_id, msg.sender, _indexCoupon);
    }

    /**
     * @dev Allows a user to claim the principal (loan repayment) of a bond after its maturity.
     *      Calls the internal function `_claimLoan`, forwarding `msg.sender` as the claimant.
     *
     * @param _id      The ID of the bond to claim repayment from.
     * @param _amount  The quantity of bond tokens the user wants to redeem for the loan.
     */
    function claimLoan(
        uint _id,
        uint _amount
    ) external whenNotPaused nonReentrant {
        _claimLoan(_id, msg.sender, _amount);
    }

    /**
     * @dev Allows the bond's issuer to deposit tokens used to pay interest (coupons) or repay the loan.
     *      Internally calls `_depositTokenForInterest`, transferring `_amount` from `msg.sender`.
     *
     * @param _id     The ID of the bond for which tokens are being deposited.
     * @param _amount The amount of tokenLoan (ERC20) to deposit.
     */
    function depositTokenForInterest(
        uint _id,
        uint _amount
    ) external whenNotPaused nonReentrant {
        _depositTokenForInterest(_id, msg.sender, _amount);
    }

    /**
     * @dev Allows the bond issuer to withdraw the collateral at the end of the bond’s life.
     *      This can be subject to conditions (e.g., issuer not in default, or certain time locks).
     *      Uses the `_onlyIssuer` modifier to restrict calls to the bond’s issuer.
     *
     * @param _id The ID of the bond from which to withdraw collateral.
     */
    function withdrawCollateral(
        uint _id
    ) external whenNotPaused nonReentrant _onlyIssuer(_id) {
        _withdrawCollateral(_id, msg.sender);
    }

    /**
     * @dev Allows the bond issuer to claim “score points” after the bond has expired,
     *      potentially improving their reputation or reducing future fees.
     *      Requires the current time to be past the bond’s expiration.
     *
     * @param _id The ID of the bond for which score points are claimed.
     */
    function claimScorePoint(
        uint _id
    ) external _onlyIssuer(_id) whenNotPaused nonReentrant {
        require(bond[_id].expiredBond <= block.timestamp, "Bond isn't Expired");
        _claimScorePoint(_id, msg.sender);
    }

    //? INTERNAL FUNCTION

    /**
     * @notice Increments the bondId counter by 1.
     *         Ensures each newly created bond has a unique ID.
     */
    function incementID() internal {
        bondId += 1;
    }

    /**
     * @dev Updates the coupon entitlements for a buyer acquiring bond tokens.
     *      Increments the future coupon claims for `_user` by `qty`, but only for coupons that haven't yet matured.
     *
     * @param _id   The ID of the bond.
     * @param _user The address of the buyer receiving coupon entitlements.
     * @param qty   The quantity of bond tokens being acquired.
     */
    function _upDateCouponBuy(uint _id, address _user, uint qty) internal {
        uint time = block.timestamp;
        for (uint i = 0; i < bond[_id].couponMaturity.length; i++) {
            // Only grant coupon rights for coupons that haven't reached maturity yet
            if (time < bond[_id].couponMaturity[i]) {
                couponToClaim[_id][_user][i] += qty;
            }
        }
    }

    /**
     * @dev Updates the coupon entitlements for a seller when they transfer bond tokens away.
     *      Decrements the seller’s future coupon claims by `qty`, but only for coupons that haven't yet matured.
     *
     * @param _id   The ID of the bond.
     * @param _user The address of the seller losing coupon entitlements.
     * @param qty   The quantity of bond tokens being transferred away.
     */
    function _upDateCouponSell(uint _id, address _user, uint qty) internal {
        uint time = block.timestamp;
        for (uint i = 0; i < bond[_id].couponMaturity.length; i++) {
            // Only remove coupon rights for coupons that haven't matured yet
            if (time < bond[_id].couponMaturity[i]) {
                couponToClaim[_id][_user][i] -= qty;
            }
        }
    }

    /**
     * @dev Internal function to create a new bond and initialize its data structures.
     *      1) Stores a new Bond struct in the `bond` mapping.
     *      2) Increments the total supply of this bond ID (`_totalSupply[_id]`).
     *      3) Sets `firstTransfer[_id] = true`, forcing the next transfer to be directed to the launcher contract.
     *      4) Mints the corresponding ERC1155 tokens to `_issuer`.
     *      5) Emits a `BondCreated` event.
     *
     * @param _id             Unique identifier for the bond.
     * @param _issuer         Address of the bond issuer.
     * @param _tokenLoan      ERC20 token used for the bond's principal.
     * @param _sizeLoan       Total loan size requested by the issuer.
     * @param _interest       Interest rate/amount per coupon.
     * @param _couponMaturity Array of timestamps indicating coupon maturities.
     * @param _expiredBond    Timestamp after which the bond is fully matured.
     * @param _tokenCollateral ERC20 token used as collateral.
     * @param _collateral     Amount of collateral locked for this bond.
     * @param _balancLoanRepay Initial balance of tokens for loan repayment (usually 0).
     * @param _amount         Total supply (quantity) of this bond token to be minted.
     * @param _describes      A descriptive string explaining the bond.
     */
    function _createNewBond(
        uint _id,
        address _issuer,
        address _tokenLoan,
        uint _sizeLoan,
        uint _interest,
        uint[] memory _couponMaturity,
        uint _expiredBond,
        address _tokenCollateral,
        uint _collateral,
        uint _balancLoanRepay,
        uint _amount,
        string calldata _describes
    ) internal {
        // Store the bond details in the mapping
        bond[_id] = Bond(
            _id,
            _issuer,
            _tokenLoan,
            _sizeLoan,
            _interest,
            _couponMaturity,
            _expiredBond,
            _tokenCollateral,
            _collateral,
            _balancLoanRepay,
            _describes,
            _amount
        );

        // Increase the total supply for this bond ID
        _totalSupply[_id] += _amount;

        // Set firstTransfer to true, ensuring the next transfer must go to the launcher
        firstTransfer[_id] = true;

        // Mint the bond tokens to the issuer
        _mint(_issuer, _id, _amount, "");

        // Emit an event to signal bond creation
        emit BondCreated(_id, _issuer, _amount);
    }

    /**
     * @dev Internal helper to transfer the collateral tokens from the issuer to this contract.
     *      The amount must be greater than zero; otherwise it reverts.
     *
     * @param _issuer          The address of the bond issuer.
     * @param _tokenCollateral The ERC20 token used as collateral.
     * @param _amount          The quantity of collateral to deposit.
     *
     * @notice
     *  The commented line below (bond[_id].balancLoanRepay += _amount;) might be needed
     *  depending on whether you want to track the collateral as part of the loan repayment balance.
     *  Currently, it's left commented out to indicate further review:
     */
    function _depositCollateralToken(
        address _issuer,
        address _tokenCollateral,
        uint _amount
    ) internal {
        require(_amount > 0, "Qta token Incorect");
        SafeERC20.safeTransferFrom(
            IERC20(_tokenCollateral),
            _issuer,
            address(this),
            _amount
        );
        //! VERIFICARE SE È DA TOGLIERE O MENO
        //!bond[_id].balancLoanRepay += _amount;
    }

    /**
     * @dev Internal function to deposit tokens (usually ERC20 specified by `bond[_id].tokenLoan`)
     *      for paying interest or principal. Increases the bond’s `balancLoanRepay`.
     *
     * @param _id      The ID of the bond for which tokens are being deposited.
     * @param _issuer  The address depositing the tokens (typically the bond issuer).
     * @param _amount  The quantity of tokens to deposit.
     */
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

    /**
     * @dev Handles the claim of a coupon (interest payment) by a user for a specific coupon index.
     *      1) Calculates how many coupons (`moltiplicator`) the user can claim, and sets it to 0 (so it can't be reused).
     *      2) Checks the bond’s current `balancLoanRepay` to see if it can fully cover the entire coupon payment.
     *         - If there's enough to cover all coupons, subtract from `balancLoanRepay`, apply a coupon fee, and transfer the remainder.
     *         - If there's not enough to cover even one coupon, subtract points from the issuer and trigger a full coupon liquidation.
     *         - If there's enough to cover some but not all coupons, execute a partial liquidation scenario.
     *
     * @param _id           The ID of the bond for which the coupon is being claimed.
     * @param _user         The address claiming the coupon.
     * @param _indexCoupon  The index in the bond's `couponMaturity` array that identifies the coupon.
     */
    function _claimCoupon(uint _id, address _user, uint _indexCoupon) internal {
        require(
            bond[_id].couponMaturity[_indexCoupon] <= block.timestamp,
            "Coupon not Expired"
        );
        // Determine how many coupon units the user is entitled to
        uint moltiplicator = couponToClaim[_id][_user][_indexCoupon];
        require(moltiplicator > 0, "Haven't Coupon for claim");
        // Reset the user's coupon claim for this index
        couponToClaim[_id][_user][_indexCoupon] = 0;

        // Calculate the total tokens owed (interest * quantity of coupons)
        uint qtaToCouponClaim = moltiplicator * bond[_id].interest;

        if (qtaToCouponClaim <= bond[_id].balancLoanRepay) {
            // 1) Enough to pay the entire coupon claim
            bond[_id].balancLoanRepay -= qtaToCouponClaim;

            // Transfer the coupon minus the coupon fee
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
            // 2) Not enough to pay even one coupon
            _subtractionPrizePoin(_id, bond[_id].issuer, moltiplicator);
            _executeLiquidationCoupon(_id, _user, moltiplicator);

            // Coupon claimed is effectively zero, since nothing was paid
            emit CouponClaimed(_user, _id, 0);
        } else if (
            qtaToCouponClaim > bond[_id].balancLoanRepay &&
            bond[_id].interest <= bond[_id].balancLoanRepay
        ) {
            // 3) Partial coverage: some coupons can be paid, but not all
            _parzialLiquidationCoupon(_id, _user, moltiplicator);
        }
    }

    /**
     * @dev Handles the claim of the loan principal by a user once the bond has expired.
     *      The user redeems a certain `_amount` of bond tokens, and in return receives the
     *      corresponding portion of the loan (if available), potentially followed by collateral
     *      liquidation if there is insufficient balance in `balancLoanRepay`.
     *
     * Steps:
     * 1) Checks if the bond is expired (`bond[_id].expiredBond <= block.timestamp`).
     * 2) Burns `_amount` from `_totalSupply[_id]`.
     * 3) If the bond has enough tokens in `balancLoanRepay` to cover `sizeLoan * _amount`,
     *    calls `_totaLiquidationForBondExpired` to repay fully.
     * 4) If partially enough, repays as many as possible, then liquidates collateral for
     *    the remainder. Points are subtracted from the issuer for the unpaid portion.
     * 5) If there's not enough to pay any portion, fully liquidates the collateral to
     *    satisfy the claim.
     *
     * @param _id     The ID of the bond being redeemed.
     * @param _user   The address claiming the loan repayment.
     * @param _amount The quantity of bond tokens the user wants to redeem.
     */
    function _claimLoan(uint _id, address _user, uint _amount) internal {
        if (numberOfLiquidations[_id] <= 4) {
            require(
                bond[_id].expiredBond <= block.timestamp,
                "Bond not be expirer"
            );
        }
        require(_amount <= _totalSupply[_id], "Amount exceeds total supply");

        // Burn the redeemed bond tokens from total supply
        _totalSupply[_id] -= _amount;

        // 1) Check if full repayment is possible: sizeLoan * _amount <= balancLoanRepay
        if (bond[_id].sizeLoan * _amount <= bond[_id].balancLoanRepay) {
            _totaLiquidationForBondExpired(_id, _user, _amount);
        }
        // 2) Check if partially enough: sizeLoan <= balancLoanRepay
        else if (bond[_id].sizeLoan <= bond[_id].balancLoanRepay) {
            // Calculate how many tokens can be covered (rounded down)
            uint capCanPay = bond[_id].balancLoanRepay / bond[_id].sizeLoan;

            // Subtract points for any portion that can't be paid in full
            _subtractionPrizePoin(_id, bond[_id].issuer, (_amount - capCanPay));

            // Repay the portion we can pay
            _totaLiquidationForBondExpired(_id, _user, capCanPay);

            // Liquidate collateral for the remainder
            _liquitationCollateralForBondExpired(
                _id,
                _user,
                (_amount - capCanPay)
            );
        }
        // 3) Not enough to cover even one token -> full collateral liquidation
        else {
            _subtractionPrizePoin(_id, bond[_id].issuer, _amount);
            _liquitationCollateralForBondExpired(_id, _user, _amount);
        }
    }

    /**
     * @dev Handles a partial liquidation when there is not enough balance to cover
     *      all coupon claims for a given multiplier (`_moltiplicator`).
     *
     * Steps:
     *  1) Calculate how many coupons can actually be paid based on the current `balancLoanRepay`.
     *  2) Transfer that partial amount to `_user`, minus a coupon fee.
     *  3) Subtract a portion of score points from the issuer to reflect partial default.
     *  4) Trigger `_executeLiquidationCoupon` to handle collateral liquidation, if any.
     *
     * @param _id             The ID of the bond being partially liquidated.
     * @param _user           The address claiming the coupon.
     * @param _moltiplicator  The amount of coupons (or multiplier of interest) requested.
     */
    function _parzialLiquidationCoupon(
        uint _id,
        address _user,
        uint _moltiplicator
    ) internal {
        uint couponCanRepay = bond[_id].balancLoanRepay / bond[_id].interest;

        // Actual token amount to pay = number of coupons we can cover * interest
        uint qtaToCouponClaim = couponCanRepay * bond[_id].interest;

        // Reduce the repay balance accordingly
        bond[_id].balancLoanRepay -= qtaToCouponClaim;

        // Transfer to the user the partial coupon, minus a coupon fee
        SafeERC20.safeTransfer(
            IERC20(bond[_id].tokenLoan),
            _user,
            qtaToCouponClaim - _couponFee(bond[_id].tokenLoan, qtaToCouponClaim)
        );

        // Emit an event indicating a partial coupon claim
        emit CouponClaimed(_user, _id, _moltiplicator);

        // Subtract prize points from the issuer for failing to pay all requested coupons
        _subtractionPrizePoin(
            _id,
            bond[_id].issuer,
            (_moltiplicator - couponCanRepay)
        );

        // Execute liquidation on remaining unpaid coupons (collateral usage)
        _executeLiquidationCoupon(_id, _user, _moltiplicator - couponCanRepay);
    }

    /**
     * @dev Executes the liquidation of coupons (and potentially the bond) when the issuer
     *      cannot fully repay the owed coupons. Each liquidation increments `numberOfLiquidations[_id]`.
     *      Depending on how many times liquidation has happened, different penalty tiers or logic apply.
     *
     *  - If this is the 1st liquidation (numberOfLiquidations[_id] == 1),
     *    calls `_logicExecuteLiquidationCoupon` with index 0.
     *  - If it's the 2nd, calls `_logicExecuteLiquidationCoupon` with index 1.
     *  - If it's the 3rd, calls `_logicExecuteLiquidationCoupon` with index 2.
     *  - If it's the 4th, fully liquidates the bond by calling `_logicExecuteLiquidationBond`.
     *
     * @param _id             The ID of the bond being liquidated.
     * @param _user           The address claiming the coupon (and triggering liquidation).
     * @param _moltiplicator  The requested amount of coupons that couldn't be fully paid.
     */
    function _executeLiquidationCoupon(
        uint _id,
        address _user,
        uint _moltiplicator
    ) internal {
        require(
            numberOfLiquidations[_id] <= 4,
            "This bond is expired or totally liquidated"
        );

        // Increment the count of liquidation events for this bond
        numberOfLiquidations[_id] += 1;

        // Depending on the count of liquidations, apply different logic
        if (numberOfLiquidations[_id] == 1) {
            _logicExecuteLiquidationCoupon(_id, 0, _moltiplicator, _user);
        } else if (numberOfLiquidations[_id] == 2) {
            _logicExecuteLiquidationCoupon(_id, 1, _moltiplicator, _user);
        } else if (numberOfLiquidations[_id] == 3) {
            _logicExecuteLiquidationCoupon(_id, 2, _moltiplicator, _user);
        } else if (numberOfLiquidations[_id] == 4) {
            // Fully liquidate the bond collateral
            _logicExecuteLiquidationBond(_id, _moltiplicator, _user);
        }
    }

    /**
     * @dev Partially liquidates the bond's collateral for a specific coupon liquidation event.
     *      Applies a penalty based on the issuer's penalty tier (`_indexPenality`) and the user's claim multiplier.
     *
     * Steps:
     *  1) Calculate the percentage of collateral to liquidate, using the issuer’s penalty rates stored in ConditionOfFee.
     *  2) Deduct a liquidation fee from that portion.
     *  3) Transfer the remaining collateral to `_user`.
     *  4) Emit a `LiquidationCoupon` event.
     *
     * @param _id             The ID of the bond being liquidated.
     * @param _indexPenality  The index into the penalityForLiquidation array (0, 1, or 2), determining the penalty rate.
     * @param _moltiplicator  The number of coupons (or equivalent multiplier) still due.
     * @param _user           The address receiving collateral in lieu of full coupon payment.
     */
    function _logicExecuteLiquidationCoupon(
        uint _id,
        uint _indexPenality,
        uint _moltiplicator,
        address _user
    ) internal {
        // Calculate collateral portion to be liquidated based on penalty
        uint percCollateralOfLiquidation = (bond[_id].collateral *
            conditionOfFee[bond[_id].issuer].penalityForLiquidation[
                _indexPenality
            ]) / 10000;

        // Divide that portion by total bond amount to get per-token collateral, then multiply by _moltiplicator
        uint percForCoupon = percCollateralOfLiquidation / bond[_id].amount;

        // Calculate the liquidation fee on the portion being transferred
        uint fee = _liquidationFee(
            bond[_id].issuer,
            bond[_id].tokenCollateral,
            (percForCoupon * _moltiplicator)
        );

        // Reduce bond collateral by net amount (collateral minus fee)
        bond[_id].collateral -= (percForCoupon * _moltiplicator) - fee;

        // Transfer the net collateral to the user
        SafeERC20.safeTransfer(
            IERC20(bond[_id].tokenCollateral),
            _user,
            (percForCoupon * _moltiplicator) - fee
        );

        // Emit an event to record the coupon liquidation
        emit LiquidationCoupon(_user, _id, _moltiplicator);
    }

    /**
     * @dev Fully or substantially liquidates the bond collateral, typically on the 4th liquidation event.
     *      The issuer loses all remaining relevant points (`_lostPoint`), and the user receives
     *      the per-token collateral for their `_moltiplicator`.
     *
     * @param _id            The ID of the bond being fully liquidated.
     * @param _moltiplicator The number of bond tokens or coupon multiplier the user is claiming.
     * @param _user          The address receiving the final collateral portion.
     */
    function _logicExecuteLiquidationBond(
        uint _id,
        uint _moltiplicator,
        address _user
    ) internal {
        // The issuer loses all prize points for this bond
        _lostPoint(_id, bond[_id].issuer);

        // Increment the liquidation counter
        numberOfLiquidations[_id] += 1;

        // Calculate collateral per token and transfer it to the user
        uint percForCoupon = bond[_id].collateral / bond[_id].amount;
        bond[_id].collateral -= percForCoupon * _moltiplicator;
        SafeERC20.safeTransfer(
            IERC20(bond[_id].tokenCollateral),
            _user,
            percForCoupon * _moltiplicator
        );

        // Emit an event for the bond liquidation
        emit LiquidationBond(_id, _moltiplicator);
    }

    /**
     * @dev Executes collateral liquidation for a bond that has expired,
     *      when the loan repayment balance is insufficient.
     *      The user redeems `_amount` of bond tokens,
     *      and receives an equivalent portion of collateral minus any liquidation fee.
     *
     * Steps:
     *  1) Increments the `freezCollateral[_id]` if it's the first time collateral is frozen.
     *  2) Calculates the per-bond-token collateral share (`collateral / bond[_id].amount`).
     *  3) Applies a liquidation fee on the portion being redeemed.
     *  4) Reduces the bond’s total collateral, updates coupon ownership,
     *     and burns `_amount` from the user's balance.
     *  5) Transfers the net collateral to `_user`.
     *  6) Emits a `LiquitationCollateralBondExpired` event.
     *
     * @param _id     The ID of the bond to liquidate.
     * @param _user   The address redeeming the bond tokens.
     * @param _amount The quantity of bond tokens being redeemed.
     */
    function _liquitationCollateralForBondExpired(
        uint _id,
        address _user,
        uint _amount
    ) internal {
        // If not previously frozen, freeze the collateral for this bond
        if (freezCollateral[_id] == 0) {
            freezCollateral[_id] += 1;
        }

        // Calculate the per-token share of the collateral
        uint collateralToLiquidate = bond[_id].collateral / bond[_id].amount;
        // Compute liquidation fee on the portion being redeemed
        uint fee = _liquidationFee(
            bond[_id].issuer,
            bond[_id].tokenLoan,
            (collateralToLiquidate * _amount)
        );

        // Update bond's collateral (subtract the portion plus fee)
        bond[_id].collateral -= (collateralToLiquidate * _amount); // + fee;

        // Remove coupon entitlements and burn the redeemed bond tokens
        _upDateCouponSell(_id, _user, _amount);
        _burn(_user, _id, _amount);

        // Transfer the net collateral to the user
        SafeERC20.safeTransfer(
            IERC20(bond[_id].tokenCollateral),
            _user,
            (collateralToLiquidate * _amount) - fee
        );

        // Emit event indicating collateral liquidation
        emit LiquitationCollateralBondExpired(_user, _id, _amount);
    }

    /**
     * @dev Performs the full repayment of a bond after its expiry, using the available `balancLoanRepay`.
     *      1) Calculates the total token amount to transfer (`sizeLoan * _amount`).
     *      2) Decrements `balancLoanRepay` by that amount.
     *      3) Updates coupon ownership, burns the bond tokens, and transfers the repaid amount (minus fees).
     *      4) Emits a `LoanClaimed` event.
     *
     * @param _id     The ID of the bond being liquidated.
     * @param _user   The address redeeming the loan.
     * @param _amount The number of bond tokens redeemed.
     */
    function _totaLiquidationForBondExpired(
        uint _id,
        address _user,
        uint _amount
    ) internal {
        // Calculate total tokens to transfer based on the amount of bond tokens redeemed
        uint valueTokenTransfer = bond[_id].sizeLoan * _amount;
        // Reduce the bond’s repay balance by the total repayment amount
        bond[_id].balancLoanRepay -= bond[_id].sizeLoan * _amount;

        // Update coupons and burn the redeemed bond tokens
        _upDateCouponSell(_id, _user, _amount);
        _burn(_user, _id, _amount);

        // Transfer the repayment tokens (minus liquidation fee) to the user
        SafeERC20.safeTransfer(
            (IERC20(bond[_id].tokenLoan)),
            _user,
            valueTokenTransfer -
                _liquidationFee(
                    bond[_id].issuer,
                    bond[_id].tokenLoan,
                    valueTokenTransfer
                )
        );
        // Emit event for successful loan claim
        emit LoanClaimed(_user, _id, _amount);
    }

    /**
     * @dev Allows the issuer to withdraw all collateral after the bond expires.
     *      - If `freezCollateral[_id]` is nonzero, a 90-day lock is enforced.
     *      - Otherwise, a standard 15-day lock applies.
     *      - Once the lock period is over, transfers any remaining collateral back to the issuer.
     *      - Emits a `CollateralWithdrawn` event.
     *
     * @param _id      The ID of the bond from which to withdraw collateral.
     * @param _issuer  The bond issuer receiving the collateral.
     */
    function _withdrawCollateral(uint _id, address _issuer) internal {
        // If collateral was previously frozen, wait 90 days past bond expiry
        if (freezCollateral[_id] != 0) {
            require(
                bond[_id].expiredBond + (90 * (1 days)) <= block.timestamp,
                "the collateral lock-up period has not yet expired, extended to 90 days for liquidation"
            );
        } else {
            // Otherwise, a standard 15-day lock after expiry
            require(
                bond[_id].expiredBond + (15 * (1 days)) <= block.timestamp,
                "the collateral lock-up period has not yet expired"
            );
        }
        // Transfer any remaining collateral to the issuer
        uint amountCollateral = bond[_id].collateral;
        bond[_id].collateral = 0;

        SafeERC20.safeTransfer(
            IERC20(bond[_id].tokenCollateral),
            _issuer,
            amountCollateral
        );

        emit CollateralWithdrawn(_issuer, _id, amountCollateral);
    }

    /**
     * @dev Assigns initial “prize points” (score-based rewards) to the bond issuer
     *      based on the total size of the loan (`_sizeLoan`). Larger loans yield
     *      higher multipliers on `_amount`.
     *
     *  - If sizeLoan is in [5e19, 1e20), multiply by 5
     *  - If sizeLoan is in [1e20, 5e20), multiply by 10
     *  - If sizeLoan is in [1e21, 5e21), multiply by 20
     *  - If sizeLoan is in [5e21, 1e22), multiply by 30
     *  - If sizeLoan is in [1e22, 1e23), multiply by 50
     *  - If sizeLoan >= 1e23, multiply by 70
     *
     * @param _id        The bond ID to which points are assigned.
     * @param _issuer    The issuer's address receiving the prize points.
     * @param _amount    The total supply of bond tokens created.
     * @param _sizeLoan  The total loan amount requested (in token units).
     */
    function _setInitialPrizePoint(
        uint _id,
        address _issuer,
        uint _amount,
        uint _sizeLoan
    ) internal {
        if (
            _sizeLoan >= 50e18 && // 5e19
            _sizeLoan < 100e18 // 1e20
        ) {
            prizeScore[_id][_issuer] = _amount * 5;
        }
        if (
            _sizeLoan >= 100e18 && // 1e20
            _sizeLoan < 500e18 // 5e20
        ) {
            prizeScore[_id][_issuer] = _amount * 10;
        }
        if (
            _sizeLoan >= 1000e18 && // 1e21
            _sizeLoan < 5000e18 // 5e21
        ) {
            prizeScore[_id][_issuer] = _amount * 20;
        }
        if (
            _sizeLoan >= 5000e18 && // 5e21
            _sizeLoan < 1e22 // 1e22
        ) {
            prizeScore[_id][_issuer] = _amount * 30;
        }
        if (
            _sizeLoan >= 1e22 && // 1e22
            _sizeLoan < 1e23
        ) {
            prizeScore[_id][_issuer] = _amount * 50;
        }
        if (_sizeLoan >= 1e23) {
            prizeScore[_id][_issuer] = _amount * 70;
        }
    }

    /**
     * @dev Updates or initializes the user's scoring and penalty conditions.
     *      Called (for example) when a new bond is created or certain conditions change.
     *
     * Logic overview:
     *  - If the user is new (score == 0) or in the "medium" range [700k, 1M], set a base score of 700k
     *    and default penalty tiers [100, 200, 400].
     *  - If the user’s score is above 1M, we consider them “high score”; apply smaller penalty tiers [50, 100, 200].
     *  - If the user’s score is between 500k and 700k, they’re “low score” => penalty tiers [200, 400, 600].
     *  - If the user’s score is < 500k, they’re “very low score” => penalty tiers [280, 450, 720].
     *
     * @param _user The address of the user whose score and penalty structure are updated.
     */
    function _setScoreForUser(address _user) internal {
        // Case 1: new user or medium range
        if (
            conditionOfFee[_user].score == 0 ||
            (conditionOfFee[_user].score <= 1000000 &&
                conditionOfFee[_user].score >= 700000)
        ) {
            uint[3] memory penalties = [uint(100), uint(200), uint(400)];
            conditionOfFee[_user] = ConditionOfFee(penalties, 700100);
            emit ScoreUpdated(_user, 700100);
        }
        // Case 2: high score (>1M)
        else if (conditionOfFee[_user].score > 1000000) {
            uint[3] memory penalties = [uint(50), uint(100), uint(200)];
            conditionOfFee[_user].penalityForLiquidation = penalties;
            emit ScoreUpdated(_user, 100000); // Possibly set to 1,000,000 or another logic as needed
        }
        // Case 3: low score [500k, 700k)
        else if (
            conditionOfFee[_user].score < 700000 &&
            conditionOfFee[_user].score >= 500000
        ) {
            uint[3] memory penalties = [uint(200), uint(400), uint(600)];
            conditionOfFee[_user].penalityForLiquidation = penalties;
            emit ScoreUpdated(_user, 500000);
        }
        // Case 4: very low score (<500k)
        else if (conditionOfFee[_user].score < 500000) {
            uint[3] memory penalties = [uint(280), uint(450), uint(720)];
            conditionOfFee[_user].penalityForLiquidation = penalties;
            emit ScoreUpdated(_user, 499999);
        }
    }

    /**
     * @dev Subtracts prize points from the issuer’s balance when the bond issuer fails
     *      to meet certain obligations. The amount subtracted depends on both the loan size
     *      and a specific multiplier factor.
     *
     * Logic:
     *  - For each range of `sizeLoan`, we call `_chekPointIsnZeri` with a different factor.
     *  - The factor determines how many points get subtracted from `prizeScore` per unit `_amount`.
     *
     * @param _id      The ID of the bond from which points are subtracted.
     * @param _issuer  The address of the bond issuer losing points.
     * @param _amount  The base amount used in calculating how many points to subtract.
     */
    function _subtractionPrizePoin(
        uint _id,
        address _issuer,
        uint _amount
    ) internal {
        // Loan in [5e19, 1e20)
        if (bond[_id].sizeLoan >= 50e18 && bond[_id].sizeLoan < 100e18) {
            _chekPointIsnZeri(_id, _issuer, _amount, 2);
        }

        // Loan in [1e20, 5e20)
        if (bond[_id].sizeLoan >= 100e18 && bond[_id].sizeLoan < 500e18) {
            _chekPointIsnZeri(_id, _issuer, _amount, 5);
        }

        // Loan in [1e21, 5e21)
        if (bond[_id].sizeLoan >= 1000e18 && bond[_id].sizeLoan < 5000e18) {
            _chekPointIsnZeri(_id, _issuer, _amount, 10);
        }

        // Loan in [5e21, 1e22)
        if (bond[_id].sizeLoan >= 5000e18 && bond[_id].sizeLoan < 1e22) {
            _chekPointIsnZeri(_id, _issuer, _amount, 15);
        }

        // Loan in [1e22, 1e23)
        if (bond[_id].sizeLoan >= 1e22 && bond[_id].sizeLoan < 1e23) {
            _chekPointIsnZeri(_id, _issuer, _amount, 25);
        }

        // Loan < 1e23
        if (bond[_id].sizeLoan < 1e23) {
            _chekPointIsnZeri(_id, _issuer, _amount, 35);
        }
    }

    /**
     * @dev Checks and subtracts the specified number of points from the issuer's prize score,
     *      ensuring it doesn't go below zero.
     *
     * - If `prizeScore[_id][_issuer]` is at least `_amount * _points`, subtract that amount.
     * - Otherwise, set the issuer's score to 0.
     *
     * @param _id      The bond ID for which the prize score is stored.
     * @param _issuer  The address whose score is adjusted.
     * @param _amount  The base amount used in the calculation.
     * @param _points  The multiplier factor applied to `_amount` when subtracting points.
     */
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

    /**
     * @dev Completely zeros out the issuer's prize score for a given bond ID.
     *      Typically called in severe default or full liquidation scenarios.
     *
     * @param _id      The bond ID whose prize score is cleared.
     * @param _issuer  The address whose score is set to zero.
     */
    function _lostPoint(uint _id, address _issuer) internal {
        prizeScore[_id][_issuer] = 0;
    }

    /**
     * @dev Allows the issuer to claim a portion of their prize points based on how many bond tokens
     *      remain in circulation. Points can only be claimed if:
     *        1) There is a non-zero balance of prizeScore left (`prizeScore[_id][_issuer] > 0`).
     *        2) The current supply percentage meets certain thresholds (10%, 25%, 50%).
     *
     * Logic summary:
     *  - If the total supply of the bond is ≤ 10% of the original `bond[_id].amount`,
     *    the issuer can claim all remaining points.
     *  - If the total supply is ≤ 25% and the issuer has claimed < 75% so far, they can claim
     *    enough points to reach 75% total claimed.
     *  - If the total supply is ≤ 50% and the issuer has claimed < 50% so far, they can claim
     *    enough points to reach 50% total claimed.
     *
     * Steps:
     *  1) Compute `totalPoints` as the sum of unclaimed (`prizeScore[_id][_issuer]`)
     *     plus already claimed (`prizeScoreAlreadyClaim[_id][_issuer]`).
     *  2) Depending on the threshold (10%, 25%, or 50%), calculate how many points can be claimed now.
     *  3) Update `prizeScore[_id][_issuer]`, `prizeScoreAlreadyClaim[_id][_issuer]`,
     *     and `conditionOfFee[_issuer].score` accordingly.
     *  4) Adjust `claimedPercentage[_id][_issuer]` to reflect how much has now been claimed in total.
     *  5) Emit a `ScoreUpdated` event with the amount of points claimed.
     *
     * @param _id     The ID of the bond whose prize points are being claimed.
     * @param _issuer The bond issuer claiming the points.
     */
    function _claimScorePoint(uint _id, address _issuer) internal {
        // Check if the issuer has any points left to claim
        require(prizeScore[_id][_issuer] > 0, "No points left to claim");

        // Total points = unclaimed + already claimed
        uint totalPoints = prizeScore[_id][_issuer] +
            prizeScoreAlreadyClaim[_id][_issuer];

        // 1) If the remaining supply is ≤ 10% of the original amount, claim all remaining points
        if (_totalSupply[_id] <= bond[_id].amount / 10) {
            uint score = prizeScore[_id][_issuer];
            prizeScoreAlreadyClaim[_id][_issuer] += score;
            prizeScore[_id][_issuer] = 0;
            conditionOfFee[_issuer].score += score;
            claimedPercentage[_id][_issuer] = 100; // 100% claimed
            emit ScoreUpdated(_issuer, score);

            // 2) If the remaining supply is ≤ 25%, the issuer can claim up to a total of 75%
        } else if (
            _totalSupply[_id] <= bond[_id].amount / 4 &&
            claimedPercentage[_id][_issuer] < 75
        ) {
            uint claimablePercentage = 75 - claimedPercentage[_id][_issuer];
            uint score = (totalPoints * claimablePercentage) / 100;
            prizeScoreAlreadyClaim[_id][_issuer] += score;
            prizeScore[_id][_issuer] -= score;
            conditionOfFee[_issuer].score += score;
            claimedPercentage[_id][_issuer] += claimablePercentage;
            emit ScoreUpdated(_issuer, score);

            // 3) If the remaining supply is ≤ 50%, the issuer can claim up to a total of 50%
        } else if (
            _totalSupply[_id] <= bond[_id].amount / 2 &&
            claimedPercentage[_id][_issuer] < 50
        ) {
            uint claimablePercentage = 50 - claimedPercentage[_id][_issuer];
            uint score = (totalPoints * claimablePercentage) / 100;
            prizeScoreAlreadyClaim[_id][_issuer] += score;
            prizeScore[_id][_issuer] -= score;
            conditionOfFee[_issuer].score += score;
            claimedPercentage[_id][_issuer] += claimablePercentage;
            emit ScoreUpdated(_issuer, score);
        }
    }

    /**
     * @dev Calculates and applies an issuance fee based on the issuer’s score.
     *      The fee is taken from the collateral amount `_amountCollateral` and deposited
     *      into the contract’s balance (`balanceContractFeesForToken`). The remainder
     *      is kept as collateral for the bond.
     *
     * Fee rates (in millesimal, i.e. “per thousand” or ‱):
     *  - score > 1,000,000 => 0.5% (5 millesimi)
     *  - 700,000 < score <= 1,000,000 => 1.5% (15 millesimi)
     *  - 500,000 < score <= 700,000 => 3% (30 millesimi)
     *  - score <= 500,000 => 5% (50 millesimi)
     *
     * @param _iusser          The address of the issuer.
     * @param _tokenAddress    The ERC20 token used as collateral.
     * @param _amountCollateral The total collateral from which the fee is subtracted.
     * @return The actual fee amount deducted from `_amountCollateral`.
     */
    function _emisionBondFee(
        address _iusser,
        address _tokenAddress,
        uint _amountCollateral
    ) internal returns (uint) {
        // High score, minimal fee
        if (conditionOfFee[_iusser].score > 1000000) {
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    5
                ); // 0.5%
        }
        // Medium-high score
        if (
            conditionOfFee[_iusser].score > 700000 &&
            conditionOfFee[_iusser].score <= 1000000
        ) {
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    15
                ); // 1.5%
        }
        // Medium-low score
        if (
            conditionOfFee[_iusser].score > 500000 &&
            conditionOfFee[_iusser].score <= 700000
        ) {
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    30
                ); // 3%
        }
        // Low score
        if (conditionOfFee[_iusser].score <= 500000) {
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    50
                ); // 5%
        }

        return 0;
    }

    /**
     * @dev Calculates and updates the contract’s fee balance during a new bond emission.
     *      1) Computes `(_amountCollateral * _fee) / 1000` as the actual fee to withhold.
     *      2) Increments `balanceContractFeesForToken[_tokenAddress]` by that amount.
     *      3) Emits `PaidFeeAtContract` event for transparency.
     *
     * @param _tokenAddress     The ERC20 token in which the fee is collected.
     * @param _amountCollateral The total collateral from which the fee is being deducted.
     * @param _fee              The fee rate in millesimal (e.g., 5 for 0.5%, 50 for 5%).
     * @return The actual fee amount after the division by 1000.
     */
    function _updateBalanceContractForEmissionNewBond(
        address _tokenAddress,
        uint _amountCollateral,
        uint _fee
    ) internal returns (uint) {
        // Calculate the fee portion of the collateral
        uint feeAmount = (_amountCollateral * _fee) / 1000;

        // Add it to the contract's fee balance
        balanceContractFeesForToken[_tokenAddress] += feeAmount;

        // Emit an event (amount logged is the product before division, for reference)
        emit PaidFeeAtContract(_tokenAddress, _fee);

        return feeAmount;
    }

    /**
     * @dev Calculates a liquidation fee during bond collateral liquidation based on
     *      the issuer’s score, deducting a percentage of `_amountCollateral` and
     *      transferring it to the contract’s fee balance.
     *
     * Fee tiers (in millesimal):
     *  - score > 1,000,000 => 0.5% (5 per 1000)
     *  - 700,000 < score <= 1,000,000 => 1.5% (15 per 1000)
     *  - 500,000 < score <= 700,000 => 3% (30 per 1000)
     *  - score <= 500,000 => 5% (50 per 1000)
     *
     * @param _iusser          The issuer’s address whose score determines the fee tier.
     * @param _tokenAddress    The ERC20 token used for collateral.
     * @param _amountCollateral The portion of collateral on which the fee is charged.
     * @return The actual fee amount deducted and added to the contract’s fee balance.
     */

    function _liquidationFee(
        address _iusser,
        address _tokenAddress,
        uint _amountCollateral
    ) internal returns (uint) {
        // High score => 0.5%
        if (conditionOfFee[_iusser].score > 1000000) {
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    LIQUIDATION_FEE[0]
                );
        }
        // Medium-high score => 1.5%
        if (
            conditionOfFee[_iusser].score > 700000 &&
            conditionOfFee[_iusser].score <= 1000000
        ) {
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    LIQUIDATION_FEE[1]
                );
        }
        // Medium-low score => 3%
        if (
            conditionOfFee[_iusser].score > 500000 &&
            conditionOfFee[_iusser].score <= 700000
        ) {
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    LIQUIDATION_FEE[2]
                );
        }
        // Low score => 5%
        if (conditionOfFee[_iusser].score <= 500000) {
            return
                _updateBalanceContractForEmissionNewBond(
                    _tokenAddress,
                    _amountCollateral,
                    LIQUIDATION_FEE[3]
                );
        }
        return 0;
    }

    /**
     * @dev Applies a fixed coupon fee of 0.5% (represented as 50 millesimal in `_upDateBalanceUserFees`)
     *      whenever a coupon is paid out. This fee is added to the contract’s fee balance.
     *
     * @param _tokenAddress The ERC20 token in which the coupon is paid.
     * @param _amount       The coupon amount from which the fee is deducted.
     * @return The actual fee taken and added to `balanceContractFeesForToken`.
     */
    function _couponFee(
        address _tokenAddress,
        uint _amount
    ) internal returns (uint) {
        // A fixed 0.5% fee on each coupon
        return _upDateBalanceUserFees(_tokenAddress, _amount, COUPON_FEE);
    }

    /**
     * @dev Calculates an expired fee at a fixed rate of 0.1% (represented as 10 millesimal),
     *      then updates the contract’s fee balance.
     *
     * @param _tokenAddress The ERC20 token used for the fee.
     * @param _amount       The amount on which the 0.1% fee is applied.
     * @return The actual fee amount added to the contract.
     */
    function _expiredFee(
        address _tokenAddress,
        uint _amount
    ) internal returns (uint) {
        // Fixed 0.1% fee
        return _upDateBalanceUserFees(_tokenAddress, _amount, 10);
    }

    /**
     * @dev Updates the contract fee balance by adding `(_amount * _fee) / 1000`.
     *      (e.g. if _fee = 50, that's 5%. If _fee = 10, that's 1%.)
     *
     * Note: The return value currently uses a 0.5% figure `((_amount * 5) / 1000)`,
     *       which might differ from the actual `_fee` used in the balance update.
     *       Review this if you intend the return to match `_fee`.
     *
     * @param _tokenAddress The ERC20 token in which the fee is collected.
     * @param _amount       The base amount from which the fee is calculated.
     * @param _fee          The fee rate in millesimal units.
     * @return A fixed 0.5% (as coded) of `_amount`. (Potentially a placeholder or to be aligned with `_fee`.)
     */
    function _upDateBalanceUserFees(
        address _tokenAddress,
        uint _amount,
        uint _fee
    ) internal returns (uint) {
        balanceContractFeesForToken[_tokenAddress] += (_amount * _fee) / 1000;
        return (_amount * _fee) / 1000;
    }

    //? VIEW & PURE FUNCTION

    /**
     * @dev Checks if an address is non-zero. Returns true if valid, false otherwise.
     */
    function _isValidAddress(address _addr) internal pure returns (bool) {
        return _addr != address(0);
    }

    /**
     * @dev Basic check to see if a given address looks like an ERC20 contract.
     *      1) Ensures the address has contract code.
     *      2) Attempts to call `totalSupply()`; if it succeeds, it's likely ERC20.
     */
    function _thisIsERC20(address _addr) internal view returns (bool) {
        // Verify the address has code (i.e., it's not externally-owned).
        if (_addr.code.length == 0) {
            return false;
        }
        // Try calling totalSupply(), which all ERC20 contracts should implement.
        try IERC20(_addr).totalSupply() returns (uint256) {
            return true;
        } catch {
            return false;
        }
    }

    /**
     * @dev Returns whether a given address is part of the ecosystem.
     * @param _contract The address to check.
     */
    function showEcosistemAddressState(
        address _contract
    ) external view returns (bool) {
        return ecosistemAddress[_contract];
    }

    /**
     * @dev Returns the current transfer fee (in WETH).
     */
    function showTransfertFee() external view returns (uint) {
        return transfertFee;
    }

    /**
     * @dev Returns the address of the launcher contract.
     */
    function showLauncherContract() external view returns (address) {
        return launcherContract;
    }

    /**
     * @dev Returns the WETH address currently set for fee payments.
     */
    function showWETHaddress() external view returns (address) {
        return WHET;
    }

    /**
     * @dev Returns the contract's accumulated fees for a specific token.
     * @param _tokenAddress The ERC20 token address.
     * @return The total fee amount accumulated for the token.
     */
    function getContractFeeBalance(
        address _tokenAddress
    ) external view returns (uint) {
        return balanceContractFeesForToken[_tokenAddress];
    }

    /**
     * @dev Returns the current value of the incremental bond ID counter.
     *      This indicates the ID that will be assigned to the next created bond.
     */
    function viewBondID() public view returns (uint) {
        return bondId;
    }

    /**
     * @dev Returns the total supply of a specific bond identified by its token ID.
     * @param id The unique ID of the bond/token.
     */
    function totalSupply(uint256 id) public view returns (uint256) {
        return _totalSupply[id];
    }

    /**
     * @dev Returns the full details of a specific bond by its ID.
     * @param _id The unique ID of the bond.
     * @return Bond The full Bond struct containing all relevant data.
     */
    function showDeatailBondForId(uint _id) public view returns (Bond memory) {
        return bond[_id];
    }

    /**
     * @dev Public function to retrieve the ConditionOfFee struct for a specific user.
     *      Primarily returns the user's penalty tiers and score.
     *
     * @param _iusser The address of the user whose ConditionOfFee is being queried.
     * @return A copy of the ConditionOfFee struct from storage.
     */
    function checkStatusPoints(
        address _iusser
    ) external view returns (ConditionOfFee memory) {
        return _checkStatusPoints(_iusser);
    }

    /**
     * @dev Internal helper that returns a storage reference to a user's ConditionOfFee struct.
     *      Used by checkStatusPoints to avoid direct external mapping access.
     *
     * @param _iusser The address of the user.
     * @return A storage reference to the user's ConditionOfFee.
     */
    function _checkStatusPoints(
        address _iusser
    ) internal view returns (ConditionOfFee storage) {
        return conditionOfFee[_iusser];
    }

    /**
     * @dev Returns the current value of the coupon fee.
     * @return The coupon fee set in the contract.
     * @notice This function provides visibility into the current coupon fee configuration.
     */
    function showCouponFee() external view returns (uint) {
        return COUPON_FEE;
    }

    /**
     * @dev Returns the current LIQUIDATION_FEE array.
     * @return An array containing the current liquidation fees.
     * @notice This function provides visibility into the current liquidation fee structure.
     */
    function showLiquidationFees() external view returns (uint[4] memory) {
        return LIQUIDATION_FEE;
    }

    /**
     * @dev Returns the penalty values for the specified category.
     * @param category The category to view:
     *        1 = mediumPenalties, 2 = highPenalties, 3 = lowPenalties, 4 = veryLowPenalties.
     * @return The array of penalties for the specified category.
     */
    function viewPenalties(
        uint category
    ) external view returns (uint[3] memory) {
        require(category >= 1 && category <= 4, "Invalid category");

        if (category == 1) {
            return mediumPenalties;
        } else if (category == 2) {
            return highPenalties;
        } else if (category == 3) {
            return lowPenalties;
        } else {
            return veryLowPenalties;
        }
    }


}
