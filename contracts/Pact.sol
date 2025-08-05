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
 * - TimeManagement: custom library for date and time operations (e.g., scheduled reward maturities).
 */
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {PactStorage} from "./PactStorage.sol";
import {IHelperPact} from "./interface/HelperPact.sol";

contract PactContract is
    PactStorage,
    ERC1155,
    Pausable,
    ReentrancyGuard,
    AccessControl
{
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

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
     * @dev Emitted upon creating a new pact (PactCreated).
     */
    event PactCreated(uint indexed id, address indexed debtor, uint amount);

    /**
     * @dev Emitted when collateral is deposited for a pact.
     */
    event CollateralDeposited(
        address indexed debtor,
        uint indexed id,
        uint amount
    );

    /**
     * @dev Emitted when collateral is withdrawn for a pact.
     */
    event CollateralWithdrawn(
        address indexed debtor,
        uint indexed id,
        uint amount
    );

    /**
     * @dev Emitted when interest tokens are deposited to cover pact rewards.
     */
    event InterestDeposited(
        address indexed debtor,
        uint indexed id,
        uint amount
    );

    /**
     * @dev Emitted when a user claims an interest scheduled reward for a pact.
     */
    event RewardClaimed(address indexed user, uint indexed id, uint amount);

    /**
     * @dev Emitted when a user claims the loan amount (principal) at pact expiry.
     */
    event LoanClaimed(address indexed user, uint indexed id, uint amount);

    /**
     * @dev Emitted when the debtor's score is updated, typically after certain events.
     */
    event ScoreUpdated(address indexed debtor, uint newScore);

    /**
     * @dev Event emitted when a scheduled reward liquidation process occurs.
     * @param user   The address of the pact holder initiating the liquidation.
     * @param id     The pact ID.
     * @param amount The amount of rewards (multiplier) involved in the liquidation.
     */
    event LiquidationReward(
        address indexed user,
        uint indexed id,
        uint indexed amount
    );

    /**
     * @dev Event emitted when the pact itself (collateral) is fully or further liquidated.
     * @param id     The pact ID that is being liquidated.
     * @param amount The number of tokens or multiplier used to compute the liquidation portion.
     */
    event LiquidationPact(uint indexed id, uint amount);

    /**
     * @dev Event emitted when collateral is liquidated at pact expiry.
     * @param user   The user receiving the liquidated collateral.
     * @param id     The pact ID being liquidated.
     * @param amount The quantity of pact tokens being redeemed against collateral.
     */
    event LiquitationCollateralPactExpired(
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
     * @dev Restricts access to functions so that only the pact's debtor can call them.
     *      Ensures that `msg.sender` matches the 'debtor' field in the Pact struct.
     */
    modifier _onlyDebtor(uint _id) {
        require(msg.sender == pact[_id].debtor, "Only Debtor");
        _;
    }

    /**
     * @dev Ensures that the provided address is valid.
     *      The address must not be the zero address (address(0)),
     *      which is commonly used as an uninitialized or invalid address.
     *
     * @param _address The address to validate.
     * @notice If `_address` is `address(0)`, the transaction will revert with "set correct Address".
     */
    modifier correctAddress(address _address) {
        require(_address != address(0), "Invalid Address");
        _;
    }

    /**
     * @dev Ensures that the provided category value is valid.
     *      The valid categories are:
     *        - 1: mediumPenalties
     *        - 2: highPenalties
     *        - 3: lowPenalties
     *        - 4: veryLowPenalties
     *      Any other value will revert with an "Invalid category" error.
     *
     * @param category The category to validate.
     */
    modifier invalidCategory(uint category) {
        require(category >= 1 && category <= 4, "Invalid category");
        _;
    }

    /**
     * @dev Constructor sets initial state:
     * - Assigns the contract owner using `Ownable(_owner)`.
     * - Initializes the ERC1155 base URI as an empty string (can be overridden later).
     * - Sets the initial pact counter (`pactId`) to 0.
     */

    constructor(
        address _owner,
        address _accountant,
        address _Ihelperpact
    ) AccessControl() ERC1155("") {
        MAX_REWARDS = 6;
        IHelperPactAddres = _Ihelperpact;

        _grantRole(AccessControl.DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(ACCOUNTANT_ROLE, _accountant);
        _grantRole(OWNER_ROLE, _owner);
    }

    /**
     * @dev Allows the contract owner to pause the contract (via OpenZeppelin's Pausable).
     *      When paused, certain functions or transfers may be restricted.
     */
    function setInPause() external onlyRole(OWNER_ROLE) {
        _pause();
    }

    /**
     * @dev Allows the contract owner to unpause the contract.
     *      Restores normal operation after a pause.
     */
    function setUnPause() external onlyRole(OWNER_ROLE) {
        _unpause();
    }

    /**
     * @dev Updates the maximum number of rewards allowed for bonds.
     *      This function can only be called by the owner of the contract.
     * @param _MAX_COUPONS The new maximum number of rewards to be set.
     */
    function setMAX_COUPONS(uint8 _MAX_COUPONS) external onlyRole(OWNER_ROLE) {
        MAX_REWARDS = _MAX_COUPONS;
    }

    /**
     * @dev Updates the fixed transfer fee (in WETH). Only the owner can modify.
     * @param _fee The new fee value.
     */
    function setTransfertFee(uint _fee) external onlyRole(OWNER_ROLE) {
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
    ) external onlyRole(OWNER_ROLE) {
        ecosistemAddress[_contract] = _state;
    }

    /**
     * @dev Sets the launcher contract address where the first pact transfer should be directed.
     *      Must not be the zero address.
     * @param _address The address of the launcher contract.
     */
    function setlauncherContract(
        address _address
    ) external onlyRole(OWNER_ROLE) correctAddress(_address) {
        launcherContract = _address;
    }

    /**
     * @dev Sets the address of the WETH token used for fee payments.
     *      Must not be the zero address.
     * @param _address The WETH contract address.
     */
    function setWETHaddress(
        address _address
    ) external onlyRole(OWNER_ROLE) correctAddress(_address) {
        WHET = _address;
    }

    /**
     * @dev Sets the scheduled reward fee used in the system.
     *      This function can only be called by the owner of the contract.
     * @param _fee The new scheduled reward fee to be set. Must be greater than zero.
     * @notice Ensures that the fee is set to a valid value to prevent incorrect configurations.
     */
    function setCOUPON_FEE(uint16 _fee) external onlyRole(OWNER_ROLE) {
        require(_fee > 0, "Set a valid fee");
        REWARD_FEE = _fee;
    }

    /**
     * @dev Sets the address of the treasury.
     *      Must not be the zero address.
     * @param _address The treasury contract address.
     */
    function setTreasuryAddress(
        address _address
    ) external onlyRole(ACCOUNTANT_ROLE) correctAddress(_address) {
        treasury = _address;
    }

    /**
     * @dev Updates a specific element in the LIQUIDATION_FEE array.
     * @param _index The index of the element to update (0-3).
     * @param _value The new value to set at the specified index.
     * @notice This function can only be called by the owner of the contract.
     * @notice Reverts if the index is out of bounds or the value is invalid.
     */
    function updateLiquidationFee(
        uint _index,
        uint16 _value
    ) external onlyRole(OWNER_ROLE) {
        require(_index < LIQUIDATION_FEE.length, "Invalid index");
        require(_value > 0, "Value must > 0");
        LIQUIDATION_FEE[_index] = _value;
    }

    /**
     * @dev Updates the entire LIQUIDATION_FEE array.
     * @param _newFees The new array of liquidation fees to set.
     * @notice This function can only be called by the owner of the contract.
     * @notice The provided array must have exactly 4 elements.
     */
    function updateLiquidationFees(
        uint16[4] memory _newFees
    ) external onlyRole(OWNER_ROLE) {
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
        uint16[3] memory newPenalties
    ) external onlyRole(OWNER_ROLE) invalidCategory(category) {
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
    function withdrawContractBalance(
        address _tokenAddress
    ) external onlyRole(ACCOUNTANT_ROLE) {
        uint balance = balanceContractFeesForToken[_tokenAddress];
        balanceContractFeesForToken[_tokenAddress] = 0;
        SafeERC20.safeTransfer(IERC20(_tokenAddress), treasury, balance);
        emit WitrawBalanceContracr(_tokenAddress, balance);
    }

    //? EXTERNAL USER FUNCTION

    /**
     * @dev Overridden safeTransferFrom that enforces:
     *      1. "firstTransfer" logic: if tokens move from `launcherContract` back to the pact debtor,
     *         the next transfer must also go to the `launcherContract`.
     *      2. A transfer fee in WETH if both `from` and `to` are outside the ecosystem.
     *
     * Steps:
     *  - If `from == launcherContract && to == pact[id].debtor`, set `firstTransfer[id] = true`.
     *    Otherwise, set it to false.
     *  - If `firstTransfer[id]` is true, require `to == launcherContract`.
     *  - If both addresses are non-ecosystem, charge `transfertFee` in WETH from `from`.
     *  - Update the scheduled reward ownership logic (`_upDateRewardSell` / `_upDateRewardBuy`).
     *  - Perform the parent `safeTransferFrom` and emit a custom event.
     *
     * @param from  The address sending (transferring) the pact tokens.
     * @param to    The address receiving the pact tokens.
     * @param id    The unique identifier (token ID) for the pact type being transferred.
     * @param amount The quantity of tokens of that pact ID to transfer.
     * @param data  Additional data, forwarded to the parent ERC1155 contract call.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override whenNotPaused nonReentrant correctAddress(to) {
        //require(to != address(0), "ERC1155: transfer to the zero address");

        // If this pact is flagged for the next transfer to go to launcher, enforce that
        if (firstTransfer[id]) {
            require(to == launcherContract, "1st tx must send Launcher");
        }

        // If tokens move from the launcher back to the debtor, force the next transfer to go to the launcher
        if (from == launcherContract && to == pact[id].debtor) {
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

        // Update scheduled reward ownership (removing from the seller, granting to the buyer)
        _upDateRewardSell(id, from, amount);
        _upDateRewardBuy(id, to, amount);

        // Execute the actual ERC1155 transfer
        super.safeTransferFrom(from, to, id, amount, data);

        // Emit a custom event
        emit SafeTransferFrom(from, to, id, amount);
    }

    /**
     * @dev Overridden safeBatchTransferFrom that:
     *      1. Applies a WETH fee if both `from` and `to` are outside the ecosystem.
     *      2. Checks and updates the `firstTransfer` logic for each token ID in the batch.
     *      3. Updates scheduled reward ownership for each pact ID transferred.
     *
     * @param from   The address sending (transferring) the pact tokens.
     * @param to     The address receiving the pact tokens.
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
    ) public override whenNotPaused nonReentrant correctAddress(to) {
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );
        //require(to != address(0), "ERC1155: transfer to the zero address");

        // If both addresses are outside the ecosystem, charge a fee for each pact ID
        if (!ecosistemAddress[from] && !ecosistemAddress[to]) {
            SafeERC20.safeTransferFrom(
                IERC20(WHET),
                from,
                address(this),
                transfertFee * ids.length
            );
            balanceContractFeesForToken[WHET] += transfertFee * ids.length;
        }

        // Update scheduled reward ownership for each ID, and enforce 'firstTransfer' rules
        uint256 idLength = ids.length;
        for (uint256 i = 0; i < idLength; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            // If this pact ID is flagged for firstTransfer, it must go to the launcher
            if (firstTransfer[id]) {
                require(to == launcherContract, "1st tx must send Launcher");
            }

            // If transferring from the launcher back to debtor, re-enable firstTransfer for next time
            if (from == launcherContract && to == pact[id].debtor) {
                firstTransfer[id] = true;
            } else {
                firstTransfer[id] = false;
            }

            // Update scheduled reward ownership (subtract from `from`, add to `to`)
            _upDateRewardSell(id, from, amount);
            _upDateRewardBuy(id, to, amount);
        }

        // Execute the actual ERC1155 batch transfer
        super.safeBatchTransferFrom(from, to, ids, amounts, data);

        // Emit a custom event for batch transfers
        emit SafeBatchTransferFrom(from, to, ids, amounts);
    }

    modifier correctAmount(uint _amount) {
        require(_amount > 0, "amount must > 0");
        _;
    }

    /**
     * @dev Creates a new pact, verifying key parameters and locking collateral.
     *      1) Checks the validity of `_tokenLoan` (must look like an ERC20).
     *      2) Ensures that loan, interest, collateral, and amount are > 0.
     *      3) Validates scheduled reward maturities and final expiry using the TimeManagment library.
     *      4) Updates the debtor's score and takes an issuance fee (`_emisionPactFee`).
     *      5) Deposits collateral and records the new pact in storage.
     *
     * Steps:
     *  - Check that `_tokenLoan` is a valid ERC20, and all necessary fields (`_sizeLoan`, `_interest`, etc.) are > 0.
     *  - Verify the scheduled reward maturity schedule (`_rewardMaturity`) is strictly increasing and ends before `_expiredPact`.
     *  - Update the debtor’s score and calculate an issuance fee.
     *  - Transfer `_collateral` from `_debtor` to the contract, subtracting the fee from the final pact collateral.
     *  - Increment pactId, then store pact details by calling `_createNewPact`.
     *  - Optionally, `_setInitialPrizePoint` seeds reward points for the debtor.
     *  - `_upDateRewardBuy` is called here for testing (may be removed or adjusted).
     *
     * @param _tokenLoan        The ERC20 token used to represent the pact's principal.
     * @param _sizeLoan         The total amount the debtor wants to borrow.
     * @param _interest         The interest (per scheduled reward) or rate to be paid.
     * @param _rewardMaturity   Array of timestamps representing the scheduled reward due dates.
     * @param _expiredPact      The timestamp after which the pact is fully matured.
     * @param _tokenCollateral  The ERC20 token used as collateral.
     * @param _collateral       The amount of collateral pledged.
     * @param _amount           The total supply (quantity) of the pact to mint (ERC1155).
     * @param _describes        A descriptive string explaining the pact.
     */
    function createNewPact(
        address _tokenLoan,
        uint _sizeLoan,
        uint _interest,
        uint64[] memory _rewardMaturity,
        uint64 _expiredPact,
        address _tokenCollateral,
        uint _collateral,
        uint _amount,
        string calldata _describes
    ) external whenNotPaused nonReentrant {
        // this helper function saver space for other implementation
        IHelperPact(IHelperPactAddres).newPactChecker(
            MAX_REWARDS,
            _rewardMaturity,
            _expiredPact,
            _tokenLoan,
            _tokenCollateral,
            _sizeLoan,
            _interest,
            _collateral,
            _amount
        );

        // Update the debtor's score and charge an issuance fee
        _setScoreForUser(msg.sender);
        //uint fee = _emisionPactFee(msg.sender, _tokenCollateral, _collateral);

        uint256 balanceBefore = IERC20(_tokenCollateral).balanceOf(
            address(this)
        );

        // Transfer collateral from debtor to this contract
        _depositCollateralToken(msg.sender, _tokenCollateral, _collateral);
        uint256 balanceAfter = IERC20(_tokenCollateral).balanceOf(
            address(this)
        );
        uint256 received = balanceAfter - balanceBefore;
        uint fee = _emisionPactFee(msg.sender, _tokenCollateral, received);
        // Prepare a unique pact ID
        uint currentId = pactId;
        incementID();

        // Store and initialize the new pact
        _createNewPact(
            currentId,
            msg.sender,
            _tokenLoan,
            _sizeLoan,
            _interest,
            _rewardMaturity,
            _expiredPact,
            _tokenCollateral,
            received - fee, // subtract the issuance fee
            0, // balancLoanRepay starts at 0
            _amount,
            _describes
        );

        // Assign initial prize score (if applicable)
        _setInitialPrizePoint(currentId, msg.sender, _amount, _sizeLoan);

        _upDateRewardBuy(currentId, msg.sender, _amount);
    }

    /**
     * @dev Allows a user to claim the scheduled reward (interest payment) for a specific pact at a given scheduled reward index.
     *      Calls the internal function `_claimReward`, forwarding `msg.sender` as the claimant.
     *
     * @param _id           The ID of the pact for which the scheduled reward is claimed.
     * @param _indexReward  The index in the pact’s `rewardMaturity` array identifying which scheduled reward is claimed.
     */
    function claimRewardForUSer(
        uint _id,
        uint8 _indexReward
    ) external whenNotPaused nonReentrant {
        _claimReward(_id, msg.sender, _indexReward);
    }

    /**
     * @dev Allows a user to claim the principal (loan repayment) of a pact after its maturity.
     *      Calls the internal function `_claimLoan`, forwarding `msg.sender` as the claimant.
     *
     * @param _id      The ID of the pact to claim repayment from.
     * @param _amount  The quantity of pact tokens the user wants to redeem for the loan.
     */
    function claimLoan(
        uint _id,
        uint _amount
    ) external whenNotPaused nonReentrant {
        _claimLoan(_id, msg.sender, _amount);
    }

    /**
     * @dev Allows the pact's debtor to deposit tokens used to pay interest (rewards) or repay the loan.
     *      Internally calls `_depositTokenForInterest`, transferring `_amount` from `msg.sender`.
     *
     * @param _id     The ID of the pact for which tokens are being deposited.
     * @param _amount The amount of tokenLoan (ERC20) to deposit.
     */
    function depositTokenForInterest(
        uint _id,
        uint _amount
    ) external whenNotPaused nonReentrant {
        _depositTokenForInterest(_id, msg.sender, _amount);
    }

    /**
     * @dev Allows the pact debtor to withdraw the collateral at the end of the pact’s life.
     *      This can be subject to conditions (e.g., debtor not in default, or certain time locks).
     *      Uses the `_onlyDebtor` modifier to restrict calls to the pact’s debtor.
     *
     * @param _id The ID of the pact from which to withdraw collateral.
     */
    function withdrawCollateral(
        uint _id
    ) external whenNotPaused nonReentrant _onlyDebtor(_id) {
        _withdrawCollateral(_id, msg.sender);
    }

    /**
     * @dev Allows the pact debtor to claim “score points” after the pact has expired,
     *      potentially improving their reputation or reducing future fees.
     *      Requires the current time to be past the pact’s expiration.
     *
     * @param _id The ID of the pact for which score points are claimed.
     */
    function claimScorePoint(
        uint _id
    ) external _onlyDebtor(_id) whenNotPaused nonReentrant {
        require(
            pact[_id].expiredPact <= uint64(block.timestamp),
            "Pact isn't Expired"
        );
        _claimScorePoint(_id, msg.sender);
    }

    //? INTERNAL FUNCTION

    /**
     * @notice Increments the pactId counter by 1.
     *         Ensures each newly created pact has a unique ID.
     */
    function incementID() internal {
        pactId += 1;
    }

    /**
     * @dev Updates the scheduled reward entitlements for a buyer acquiring pact tokens.
     *      Increments the future scheduled reward claims for `_user` by `qty`, but only for rewards that haven't yet matured.
     *
     * @param _id   The ID of the pact.
     * @param _user The address of the buyer receiving scheduled reward entitlements.
     * @param qty   The quantity of pact tokens being acquired.
     */
    function _upDateRewardBuy(uint _id, address _user, uint qty) internal {
        uint64 time = uint64(block.timestamp);
        uint8 length = uint8(pact[_id].rewardMaturity.length);
        for (uint8 i = 0; i < length; i++) {
            // Only grant scheduled reward rights for rewards that haven't reached maturity yet
            if (time < pact[_id].rewardMaturity[i]) {
                rewardToClaim[_id][_user][i] += qty;
            }
        }
    }

    /**
     * @dev Updates the scheduled reward entitlements for a seller when they transfer pact tokens away.
     *      Decrements the seller’s future scheduled reward claims by `qty`, but only for rewards that haven't yet matured.
     *
     * @param _id   The ID of the pact.
     * @param _user The address of the seller losing scheduled reward entitlements.
     * @param qty   The quantity of pact tokens being transferred away.
     */
    function _upDateRewardSell(uint _id, address _user, uint qty) internal {
        uint64 time = uint64(block.timestamp);
        uint length = pact[_id].rewardMaturity.length;
        for (uint i = 0; i < length; i++) {
            // Only remove scheduled reward rights for rewards that haven't matured yet
            if (time < pact[_id].rewardMaturity[i]) {
                require(
                    rewardToClaim[_id][_user][i] >= qty,
                    "Insufficient rewards"
                );
                rewardToClaim[_id][_user][i] -= qty;
            }
        }
    }

    /**
     * @dev Internal function to create a new pact and initialize its data structures.
     *      1) Stores a new Pact struct in the `pact` mapping.
     *      2) Increments the total supply of this pact ID (`_totalSupply[_id]`).
     *      3) Sets `firstTransfer[_id] = true`, forcing the next transfer to be directed to the launcher contract.
     *      4) Mints the corresponding ERC1155 tokens to `_debtor`.
     *      5) Emits a `PactCreated` event.
     *
     * @param _id             Unique identifier for the pact.
     * @param _debtor         Address of the pact debtor.
     * @param _tokenLoan      ERC20 token used for the pact's principal.
     * @param _sizeLoan       Total loan size requested by the debtor.
     * @param _interest       Reward rate/amount per scheduled reward.
     * @param _rewardMaturity Array of timestamps indicating scheduled reward maturities.
     * @param _expiredPact    Timestamp after which the pact is fully matured.
     * @param _tokenCollateral ERC20 token used as collateral.
     * @param _collateral     Amount of collateral locked for this pact.
     * @param _balancLoanRepay Initial balance of tokens for loan repayment (usually 0).
     * @param _amount         Total supply (quantity) of this pact token to be minted.
     * @param _describes      A descriptive string explaining the pact.
     */
    function _createNewPact(
        uint _id,
        address _debtor,
        address _tokenLoan,
        uint _sizeLoan,
        uint _interest,
        uint64[] memory _rewardMaturity,
        uint64 _expiredPact,
        address _tokenCollateral,
        uint _collateral,
        uint _balancLoanRepay,
        uint _amount,
        string calldata _describes
    ) internal {
        // Store the pact details in the mapping
        pact[_id] = Pact(
            _id,
            _debtor,
            _tokenLoan,
            _sizeLoan,
            _interest,
            _rewardMaturity,
            _expiredPact,
            _tokenCollateral,
            _collateral,
            _balancLoanRepay,
            _describes,
            _amount
        );

        // Increase the total supply for this pact ID
        _totalSupply[_id] += _amount;

        // Set firstTransfer to true, ensuring the next transfer must go to the launcher
        firstTransfer[_id] = true;

        // Mint the pact tokens to the debtor
        _mint(_debtor, _id, _amount, "");

        // Emit an event to signal pact creation
        emit PactCreated(_id, _debtor, _amount);
    }

    /**
     * @dev Internal helper to transfer the collateral tokens from the debtor to this contract.
     *      The amount must be greater than zero; otherwise it reverts.
     *
     * @param _debtor          The address of the pact debtor.
     * @param _tokenCollateral The ERC20 token used as collateral.
     * @param _amount          The quantity of collateral to deposit.
     *
     * @notice
     *  The commented line below (pact[_id].balancLoanRepay += _amount;) might be needed
     *  depending on whether you want to track the collateral as part of the loan repayment balance.
     *  Currently, it's left commented out to indicate further review:
     */
    function _depositCollateralToken(
        address _debtor,
        address _tokenCollateral,
        uint _amount
    ) internal correctAmount(_amount) {
        //require(_amount > 0, "Qta token Incorect");
        SafeERC20.safeTransferFrom(
            IERC20(_tokenCollateral),
            _debtor,
            address(this),
            _amount
        );
        //! VERIFICARE SE È DA TOGLIERE O MENO
        //!pact[_id].balancLoanRepay += _amount;
    }

    /**
     * @dev Internal function to deposit tokens (usually ERC20 specified by `pact[_id].tokenLoan`)
     *      for paying interest or principal. Increases the pact’s `balancLoanRepay`.
     *
     * @param _id      The ID of the pact for which tokens are being deposited.
     * @param _debtor  The address depositing the tokens (typically the pact debtor).
     * @param _amount  The quantity of tokens to deposit.
     */
    function _depositTokenForInterest(
        uint _id,
        address _debtor,
        uint _amount
    ) internal correctAmount(_amount) {
        require(!depositIsClose[_id], "Deposit is Close");
        Pact storage b = pact[_id];
        if (maxInterestDeposit[_id] == 0) {
            uint256 interestTotal = b.interest * b.rewardMaturity.length;
            maxInterestDeposit[_id] =
                (b.sizeLoan + interestTotal) *
                _totalSupply[_id];
        }
        require(
            _amount <= maxInterestDeposit[_id],
            "Cannot deposit more than allowed"
        );

        if (maxInterestDeposit[_id] == 0) {
            depositIsClose[_id] = true;
        }

        SafeERC20.safeTransferFrom(
            IERC20(b.tokenLoan),
            _debtor,
            address(this),
            _amount
        );
        b.balancLoanRepay += _amount;
        emit InterestDeposited(_debtor, _id, _amount);
        maxInterestDeposit[_id] -= _amount;
    }

    /**
     * @dev Handles the claim of a scheduled reward (interest payment) by a user for a specific scheduled reward index.
     *      1) Calculates how many rewards (`moltiplicator`) the user can claim, and sets it to 0 (so it can't be reused).
     *      2) Checks the pact’s current `balancLoanRepay` to see if it can fully cover the entire scheduled reward payment.
     *         - If there's enough to cover all rewards, subtract from `balancLoanRepay`, apply a scheduled reward fee, and transfer the remainder.
     *         - If there's not enough to cover even one scheduled reward, subtract points from the debtor and trigger a full scheduled reward liquidation.
     *         - If there's enough to cover some but not all rewards, execute a partial liquidation scenario.
     *
     * @param _id           The ID of the pact for which the scheduled reward is being claimed.
     * @param _user         The address claiming the scheduled reward.
     * @param _indexReward  The index in the pact's `rewardMaturity` array that identifies the scheduled reward.
     */
    function _claimReward(uint _id, address _user, uint _indexReward) internal {
        Pact storage b = pact[_id];
        require(
            b.rewardMaturity[_indexReward] <= uint64(block.timestamp),
            "Scheduled Reward not Expired"
        );
        // Determine how many scheduled reward units the user is entitled to
        uint moltiplicator = rewardToClaim[_id][_user][_indexReward];
        require(moltiplicator > 0, "Haven't Scheduled Reward for claim");
        // Reset the user's scheduled reward claim for this index
        rewardToClaim[_id][_user][_indexReward] = 0;

        // Calculate the total tokens owed (interest * quantity of rewards)
        uint qtaToRewardClaim = moltiplicator * pact[_id].interest;

        if (qtaToRewardClaim <= b.balancLoanRepay) {
            // 1) Enough to pay the entire scheduled reward claim
            b.balancLoanRepay -= qtaToRewardClaim;

            // Transfer the scheduled reward minus the scheduled reward fee
            SafeERC20.safeTransfer(
                IERC20(b.tokenLoan),
                _user,
                qtaToRewardClaim - _couponFee(b.tokenLoan, qtaToRewardClaim)
            );

            emit RewardClaimed(_user, _id, qtaToRewardClaim);
        } else if (
            qtaToRewardClaim > b.balancLoanRepay &&
            b.interest > b.balancLoanRepay
        ) {
            // 2) Not enough to pay even one scheduled reward
            _subtractionPrizePoin(_id, b.debtor, moltiplicator);
            _executeLiquidationReward(_id, _user, moltiplicator);

            // Scheduled Reward claimed is effectively zero, since nothing was paid
            emit RewardClaimed(_user, _id, 0);
        } else if (
            qtaToRewardClaim > b.balancLoanRepay &&
            b.interest <= b.balancLoanRepay
        ) {
            // 3) Partial coverage: some rewards can be paid, but not all
            _parzialLiquidationReward(_id, _user, moltiplicator);
        }
    }

    /**
     * @dev Handles the claim of the loan principal by a user once the pact has expired.
     *      The user redeems a certain `_amount` of pact tokens, and in return receives the
     *      corresponding portion of the loan (if available), potentially followed by collateral
     *      liquidation if there is insufficient balance in `balancLoanRepay`.
     *
     * Steps:
     * 1) Checks if the pact is expired (`pact[_id].expiredPact <= block.timestamp`).
     * 2) Burns `_amount` from `_totalSupply[_id]`.
     * 3) If the pact has enough tokens in `balancLoanRepay` to cover `sizeLoan * _amount`,
     *    calls `_totaLiquidationForPactExpired` to repay fully.
     * 4) If partially enough, repays as many as possible, then liquidates collateral for
     *    the remainder. Points are subtracted from the debtor for the unpaid portion.
     * 5) If there's not enough to pay any portion, fully liquidates the collateral to
     *    satisfy the claim.
     *
     * @param _id     The ID of the pact being redeemed.
     * @param _user   The address claiming the loan repayment.
     * @param _amount The quantity of pact tokens the user wants to redeem.
     */
    function _claimLoan(uint _id, address _user, uint _amount) internal {
        Pact storage b = pact[_id];
        if (numberOfLiquidations[_id] <= 4) {
            require(b.expiredPact <= block.timestamp, "Pact not be expirer");
        }
        require(_amount <= _totalSupply[_id], "Amount exceeds total supply");

        // Burn the redeemed pact tokens from total supply
        _totalSupply[_id] -= _amount;

        // 1) Check if full repayment is possible: sizeLoan * _amount <= balancLoanRepay
        if (b.sizeLoan * _amount <= b.balancLoanRepay) {
            _totaLiquidationForPactExpired(_id, _user, _amount);
        }
        // 2) Check if partially enough: sizeLoan <= balancLoanRepay
        else if (b.sizeLoan <= b.balancLoanRepay) {
            // Calculate how many tokens can be covered (rounded down)
            uint capCanPay = b.balancLoanRepay / b.sizeLoan;

            // Subtract points for any portion that can't be paid in full
            _subtractionPrizePoin(_id, b.debtor, (_amount - capCanPay));

            // Repay the portion we can pay
            _totaLiquidationForPactExpired(_id, _user, capCanPay);

            // Liquidate collateral for the remainder
            _liquitationCollateralForPactExpired(
                _id,
                _user,
                (_amount - capCanPay)
            );
        }
        // 3) Not enough to cover even one token -> full collateral liquidation
        else {
            _subtractionPrizePoin(_id, b.debtor, _amount);
            _liquitationCollateralForPactExpired(_id, _user, _amount);
        }
    }

    /**
     * @dev Handles a partial liquidation when there is not enough balance to cover
     *      all scheduled reward claims for a given multiplier (`_moltiplicator`).
     *
     * Steps:
     *  1) Calculate how many rewards can actually be paid based on the current `balancLoanRepay`.
     *  2) Transfer that partial amount to `_user`, minus a scheduled reward fee.
     *  3) Subtract a portion of score points from the debtor to reflect partial default.
     *  4) Trigger `_executeLiquidationReward` to handle collateral liquidation, if any.
     *
     * @param _id             The ID of the pact being partially liquidated.
     * @param _user           The address claiming the scheduled reward.
     * @param _moltiplicator  The amount of rewards (or multiplier of interest) requested.
     */
    function _parzialLiquidationReward(
        uint _id,
        address _user,
        uint _moltiplicator
    ) internal {
        Pact storage b = pact[_id];
        uint rewardCanRepay = b.balancLoanRepay / b.interest;

        // Actual token amount to pay = number of rewards we can cover * interest
        uint qtaToRewardClaim = rewardCanRepay * b.interest;

        // Reduce the repay balance accordingly
        b.balancLoanRepay -= qtaToRewardClaim;

        // Transfer to the user the partial scheduled reward, minus a scheduled reward fee
        SafeERC20.safeTransfer(
            IERC20(b.tokenLoan),
            _user,
            qtaToRewardClaim - _couponFee(b.tokenLoan, qtaToRewardClaim)
        );

        // Emit an event indicating a partial scheduled reward claim
        emit RewardClaimed(_user, _id, _moltiplicator);

        // Subtract prize points from the debtor for failing to pay all requested rewards
        _subtractionPrizePoin(_id, b.debtor, (_moltiplicator - rewardCanRepay));

        // Execute liquidation on remaining unpaid rewards (collateral usage)
        _executeLiquidationReward(_id, _user, _moltiplicator - rewardCanRepay);
    }

    /**
     * @dev Executes the liquidation of rewards (and potentially the pact) when the debtor
     *      cannot fully repay the owed rewards. Each liquidation increments `numberOfLiquidations[_id]`.
     *      Depending on how many times liquidation has happened, different penalty tiers or logic apply.
     *
     *  - If this is the 1st liquidation (numberOfLiquidations[_id] == 1),
     *    calls `_logicExecuteLiquidationReward` with index 0.
     *  - If it's the 2nd, calls `_logicExecuteLiquidationReward` with index 1.
     *  - If it's the 3rd, calls `_logicExecuteLiquidationReward` with index 2.
     *  - If it's the 4th, fully liquidates the pact by calling `_logicExecuteLiquidationPact`.
     *
     * @param _id             The ID of the pact being liquidated.
     * @param _user           The address claiming the scheduled reward (and triggering liquidation).
     * @param _moltiplicator  The requested amount of rewards that couldn't be fully paid.
     */
    function _executeLiquidationReward(
        uint _id,
        address _user,
        uint _moltiplicator
    ) internal {
        // Cattura in locale il numero di liquidazioni per evitare più SLOAD
        uint8 n = numberOfLiquidations[_id];
        require(n <= 4, "This pact is expired or totally liquidated");
        n++;
        numberOfLiquidations[_id] = n;
        if (n < 4) {
            _logicExecuteLiquidationReward(_id, n - 1, _moltiplicator, _user);
        } else {
            _logicExecuteLiquidationPact(_id, _moltiplicator, _user);
        }
    }

    /**
     * @dev Partially liquidates the pact's collateral for a specific scheduled reward liquidation event.
     *      Applies a penalty based on the debtor's penalty tier (`_indexPenality`) and the user's claim multiplier.
     *
     * Steps:
     *  1) Calculate the percentage of collateral to liquidate, using the debtor’s penalty rates stored in ConditionOfFee.
     *  2) Deduct a liquidation fee from that portion.
     *  3) Transfer the remaining collateral to `_user`.
     *  4) Emit a `LiquidationReward` event.
     *
     * @param _id             The ID of the pact being liquidated.
     * @param _indexPenality  The index into the penalityForLiquidation array (0, 1, or 2), determining the penalty rate.
     * @param _moltiplicator  The number of rewards (or equivalent multiplier) still due.
     * @param _user           The address receiving collateral in lieu of full scheduled reward payment.
     */
    function _logicExecuteLiquidationReward(
        uint _id,
        uint _indexPenality,
        uint _moltiplicator,
        address _user
    ) internal {
        Pact storage b = pact[_id];
        // Calculate collateral portion to be liquidated based on penalty
        uint percCollateralOfLiquidation = (b.collateral *
            conditionOfFee[b.debtor].penalityForLiquidation[_indexPenality]) /
            10000;

        // Divide that portion by total pact amount to get per-token collateral, then multiply by _moltiplicator
        uint percForReward = percCollateralOfLiquidation / b.amount;

        // Calculate the liquidation fee on the portion being transferred
        uint fee = _liquidationFee(
            b.debtor,
            b.tokenCollateral,
            (percForReward * _moltiplicator)
        );

        // Reduce pact collateral by net amount (collateral minus fee)
        b.collateral -= (percForReward * _moltiplicator) - fee;

        // Transfer the net collateral to the user
        SafeERC20.safeTransfer(
            IERC20(b.tokenCollateral),
            _user,
            (percForReward * _moltiplicator) - fee
        );
        emit LiquidationReward(_user, _id, _moltiplicator);
    }

    /**
     * @dev Fully or substantially liquidates the pact collateral, typically on the 4th liquidation event.
     *      The debtor loses all remaining relevant points (`_lostPoint`), and the user receives
     *      the per-token collateral for their `_moltiplicator`.
     *
     * @param _id            The ID of the pact being fully liquidated.
     * @param _moltiplicator The number of pact tokens or scheduled reward multiplier the user is claiming.
     * @param _user          The address receiving the final collateral portion.
     */
    function _logicExecuteLiquidationPact(
        uint _id,
        uint _moltiplicator,
        address _user
    ) internal {
        Pact storage b = pact[_id];
        // The debtor loses all prize points for this pact
        _lostPoint(_id, b.debtor);

        // Increment the liquidation counter
        numberOfLiquidations[_id] += 1;

        // Calculate collateral per token and transfer it to the user
        uint percForReward = b.collateral / b.amount;
        b.collateral -= percForReward * _moltiplicator;
        SafeERC20.safeTransfer(
            IERC20(b.tokenCollateral),
            _user,
            percForReward * _moltiplicator
        );

        // Emit an event for the pact liquidation
        emit LiquidationPact(_id, _moltiplicator);
    }

    /**
     * @dev Executes collateral liquidation for a pact that has expired,
     *      when the loan repayment balance is insufficient.
     *      The user redeems `_amount` of pact tokens,
     *      and receives an equivalent portion of collateral minus any liquidation fee.
     *
     * Steps:
     *  1) Increments the `freezCollateral[_id]` if it's the first time collateral is frozen.
     *  2) Calculates the per-pact-token collateral share (`collateral / pact[_id].amount`).
     *  3) Applies a liquidation fee on the portion being redeemed.
     *  4) Reduces the pact’s total collateral, updates scheduled reward ownership,
     *     and burns `_amount` from the user's balance.
     *  5) Transfers the net collateral to `_user`.
     *  6) Emits a `LiquitationCollateralPactExpired` event.
     *
     * @param _id     The ID of the pact to liquidate.
     * @param _user   The address redeeming the pact tokens.
     * @param _amount The quantity of pact tokens being redeemed.
     */
    function _liquitationCollateralForPactExpired(
        uint _id,
        address _user,
        uint _amount
    ) internal {
        // If not previously frozen, freeze the collateral for this pact
        Pact storage b = pact[_id];
        if (freezCollateral[_id] == 0) {
            freezCollateral[_id] += 1;
            liquidationFactor[_id] = b.collateral / b.amount;
        }

        // Calculate the per-token share of the collateral
        //uint collateralToLiquidate = pact[_id].collateral / pact[_id].amount;
        // Compute liquidation fee on the portion being redeemed
        uint fee = _liquidationFee(
            b.debtor,
            b.tokenLoan,
            (liquidationFactor[_id] * _amount)
        );

        // Update pact's collateral (subtract the portion plus fee)
        b.collateral -= (liquidationFactor[_id] * _amount); // + fee;

        // Remove scheduled reward entitlements and burn the redeemed pact tokens
        _upDateRewardSell(_id, _user, _amount);
        _burn(_user, _id, _amount);

        // Transfer the net collateral to the user
        SafeERC20.safeTransfer(
            IERC20(b.tokenCollateral),
            _user,
            (liquidationFactor[_id] * _amount) - fee
        );

        // Emit event indicating collateral liquidation
        emit LiquitationCollateralPactExpired(_user, _id, _amount);
    }

    /**
     * @dev Performs the full repayment of a pact after its expiry, using the available `balancLoanRepay`.
     *      1) Calculates the total token amount to transfer (`sizeLoan * _amount`).
     *      2) Decrements `balancLoanRepay` by that amount.
     *      3) Updates scheduled reward ownership, burns the pact tokens, and transfers the repaid amount (minus fees).
     *      4) Emits a `LoanClaimed` event.
     *
     * @param _id     The ID of the pact being liquidated.
     * @param _user   The address redeeming the loan.
     * @param _amount The number of pact tokens redeemed.
     */
    function _totaLiquidationForPactExpired(
        uint _id,
        address _user,
        uint _amount
    ) internal {
        Pact storage b = pact[_id];
        // Calculate total tokens to transfer based on the amount of pact tokens redeemed
        uint valueTokenTransfer = b.sizeLoan * _amount;
        // Reduce the pact’s repay balance by the total repayment amount
        b.balancLoanRepay -= b.sizeLoan * _amount;

        // Update rewards and burn the redeemed pact tokens
        _upDateRewardSell(_id, _user, _amount);
        _burn(_user, _id, _amount);

        // Transfer the repayment tokens (minus liquidation fee) to the user
        SafeERC20.safeTransfer(
            (IERC20(b.tokenLoan)),
            _user,
            valueTokenTransfer -
                _liquidationFee(b.debtor, b.tokenLoan, valueTokenTransfer)
        );
        // Emit event for successful loan claim
        emit LoanClaimed(_user, _id, _amount);
    }

    /**
     * @dev Allows the debtor to withdraw all collateral after the pact expires.
     *      - If `freezCollateral[_id]` is nonzero, a 90-day lock is enforced.
     *      - Otherwise, a standard 15-day lock applies.
     *      - Once the lock period is over, transfers any remaining collateral back to the debtor.
     *      - Emits a `CollateralWithdrawn` event.
     *
     * @param _id      The ID of the pact from which to withdraw collateral.
     * @param _debtor  The pact debtor receiving the collateral.
     */
    function _withdrawCollateral(uint _id, address _debtor) internal {
        // If collateral was previously frozen, wait 90 days past pact expiry
        Pact storage b = pact[_id];
        if (freezCollateral[_id] != 0) {
            require(
                b.expiredPact + (90 * (1 days)) <= block.timestamp,
                "the collateral lock-up period has not yet expired, extended to 90 days for liquidation"
            );
        } else {
            // Otherwise, a standard 15-day lock after expiry
            require(
                b.expiredPact + (15 * (1 days)) <= block.timestamp,
                "the collateral lock-up period has not yet expired"
            );
        }
        // Transfer any remaining collateral to the debtor
        uint amountCollateral = b.collateral;
        b.collateral = 0;

        SafeERC20.safeTransfer(
            IERC20(b.tokenCollateral),
            _debtor,
            amountCollateral
        );

        emit CollateralWithdrawn(_debtor, _id, amountCollateral);
    }

    /**
     * @dev Assigns initial “prize points” (score-based rewards) to the pact debtor
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
     * @param _id        The pact ID to which points are assigned.
     * @param _debtor    The debtor's address receiving the prize points.
     * @param _amount    The total supply of pact tokens created.
     * @param _sizeLoan  The total loan amount requested (in token units).
     */
    function _setInitialPrizePoint(
        uint _id,
        address _debtor,
        uint _amount,
        uint _sizeLoan
    ) internal {
        uint newScore;
        if (_sizeLoan >= 1e23) {
            newScore = _amount * 70;
        } else if (_sizeLoan >= 1e22) {
            newScore = _amount * 50;
        } else if (_sizeLoan >= 5000e18) {
            newScore = _amount * 30;
        } else if (_sizeLoan >= 1000e18) {
            newScore = _amount * 20;
        } else if (_sizeLoan >= 100e18) {
            newScore = _amount * 10;
        } else if (_sizeLoan >= 50e18) {
            newScore = _amount * 5;
        } else {
            newScore = 0; // Se _sizeLoan non soddisfa nessuna condizione, opzionale
        }
        prizeScore[_id][_debtor] = newScore;
    }

    /**
     * @dev Updates or initializes the user's scoring and penalty conditions.
     *      Called (for example) when a new pact is created or certain conditions change.
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
        uint score = conditionOfFee[_user].score; // Legge il punteggio una sola volta

        if (score == 0 || (score >= 700000 && score <= 1000000)) {
            // Caso: nuovo utente o punteggio nella fascia "media" [700k, 1M]
            uint16[3] memory penalties = [100, 200, 400];
            conditionOfFee[_user] = ConditionOfFee(penalties, 700100);
            emit ScoreUpdated(_user, 700100);
        } else if (score > 1000000) {
            // Caso: punteggio alto (>1M)
            uint16[3] memory penalties = [uint16(50), uint16(100), uint16(200)];
            conditionOfFee[_user].penalityForLiquidation = penalties;
            emit ScoreUpdated(_user, 100000);
        } else if (score >= 500000 && score < 700000) {
            // Caso: punteggio basso [500k, 700k)
            uint16[3] memory penalties = [200, 400, 600];
            conditionOfFee[_user].penalityForLiquidation = penalties;
            emit ScoreUpdated(_user, 500000);
        } else {
            // Caso: punteggio molto basso (<500k)
            uint16[3] memory penalties = [280, 450, 720];
            conditionOfFee[_user].penalityForLiquidation = penalties;
            emit ScoreUpdated(_user, 499999);
        }
    }

    /**
     * @dev Subtracts prize points from the debtor’s balance when the pact debtor fails
     *      to meet certain obligations. The amount subtracted depends on both the loan size
     *      and a specific multiplier factor.
     *
     * Logic:
     *  - For each range of `sizeLoan`, we call `_chekPointIsnZeri` with a different factor.
     *  - The factor determines how many points get subtracted from `prizeScore` per unit `_amount`.
     *
     * @param _id      The ID of the pact from which points are subtracted.
     * @param _debtor  The address of the pact debtor losing points.
     * @param _amount  The base amount used in calculating how many points to subtract.
     */
    function _subtractionPrizePoin(
        uint _id,
        address _debtor,
        uint _amount
    ) internal {
        Pact storage b = pact[_id];
        // Loan in [5e19, 1e20)
        if (b.sizeLoan >= 50e18 && b.sizeLoan < 100e18) {
            _chekPointIsnZeri(_id, _debtor, _amount, 2);
        }

        // Loan in [1e20, 5e20)
        if (b.sizeLoan >= 100e18 && b.sizeLoan < 500e18) {
            _chekPointIsnZeri(_id, _debtor, _amount, 5);
        }

        // Loan in [1e21, 5e21)
        if (b.sizeLoan >= 1000e18 && b.sizeLoan < 5000e18) {
            _chekPointIsnZeri(_id, _debtor, _amount, 10);
        }

        // Loan in [5e21, 1e22)
        if (b.sizeLoan >= 5000e18 && b.sizeLoan < 1e22) {
            _chekPointIsnZeri(_id, _debtor, _amount, 15);
        }

        // Loan in [1e22, 1e23)
        if (b.sizeLoan >= 1e22 && b.sizeLoan < 1e23) {
            _chekPointIsnZeri(_id, _debtor, _amount, 25);
        }

        // Loan < 1e23
        if (b.sizeLoan < 1e23) {
            _chekPointIsnZeri(_id, _debtor, _amount, 35);
        }
    }

    /**
     * @dev Checks and subtracts the specified number of points from the debtor's prize score,
     *      ensuring it doesn't go below zero.
     *
     * - If `prizeScore[_id][_debtor]` is at least `_amount * _points`, subtract that amount.
     * - Otherwise, set the debtor's score to 0.
     *
     * @param _id      The pact ID for which the prize score is stored.
     * @param _debtor  The address whose score is adjusted.
     * @param _amount  The base amount used in the calculation.
     * @param _points  The multiplier factor applied to `_amount` when subtracting points.
     */
    function _chekPointIsnZeri(
        uint _id,
        address _debtor,
        uint _amount,
        uint _points
    ) internal {
        if (prizeScore[_id][_debtor] >= _amount * _points) {
            prizeScore[_id][_debtor] -= _amount * _points;
        } else {
            prizeScore[_id][_debtor] = 0;
        }
    }

    /**
     * @dev Completely zeros out the debtor's prize score for a given pact ID.
     *      Typically called in severe default or full liquidation scenarios.
     *
     * @param _id      The pact ID whose prize score is cleared.
     * @param _debtor  The address whose score is set to zero.
     */
    function _lostPoint(uint _id, address _debtor) internal {
        prizeScore[_id][_debtor] = 0;
    }

    /**
     * @dev Allows the debtor to claim a portion of their prize points based on how many pact tokens
     *      remain in circulation. Points can only be claimed if:
     *        1) There is a non-zero balance of prizeScore left (`prizeScore[_id][_debtor] > 0`).
     *        2) The current supply percentage meets certain thresholds (10%, 25%, 50%).
     *
     * Logic summary:
     *  - If the total supply of the pact is ≤ 10% of the original `pact[_id].amount`,
     *    the debtor can claim all remaining points.
     *  - If the total supply is ≤ 25% and the debtor has claimed < 75% so far, they can claim
     *    enough points to reach 75% total claimed.
     *  - If the total supply is ≤ 50% and the debtor has claimed < 50% so far, they can claim
     *    enough points to reach 50% total claimed.
     *
     * Steps:
     *  1) Compute `totalPoints` as the sum of unclaimed (`prizeScore[_id][_debtor]`)
     *     plus already claimed (`prizeScoreAlreadyClaim[_id][_debtor]`).
     *  2) Depending on the threshold (10%, 25%, or 50%), calculate how many points can be claimed now.
     *  3) Update `prizeScore[_id][_debtor]`, `prizeScoreAlreadyClaim[_id][_debtor]`,
     *     and `conditionOfFee[_debtor].score` accordingly.
     *  4) Adjust `claimedPercentage[_id][_debtor]` to reflect how much has now been claimed in total.
     *  5) Emit a `ScoreUpdated` event with the amount of points claimed.
     *
     * @param _id     The ID of the pact whose prize points are being claimed.
     * @param _debtor The pact debtor claiming the points.
     */
    function _claimScorePoint(uint _id, address _debtor) internal {
        // Check if the debtor has any points left to claim
        require(prizeScore[_id][_debtor] > 0, "No points left to claim");

        // Total points = unclaimed + already claimed
        uint totalPoints = prizeScore[_id][_debtor] +
            prizeScoreAlreadyClaim[_id][_debtor];

        // 1) If the remaining supply is ≤ 10% of the original amount, claim all remaining points
        if (_totalSupply[_id] <= pact[_id].amount / 10) {
            uint score = prizeScore[_id][_debtor];
            prizeScoreAlreadyClaim[_id][_debtor] += score;
            prizeScore[_id][_debtor] = 0;
            conditionOfFee[_debtor].score += score;
            claimedPercentage[_id][_debtor] = uint8(100); // 100% claimed
            emit ScoreUpdated(_debtor, score);

            // 2) If the remaining supply is ≤ 25%, the debtor can claim up to a total of 75%
        } else if (
            _totalSupply[_id] <= pact[_id].amount / 4 &&
            claimedPercentage[_id][_debtor] < 75
        ) {
            uint8 claimablePercentage = 75 - claimedPercentage[_id][_debtor];
            uint score = (totalPoints * claimablePercentage) / 100;
            prizeScoreAlreadyClaim[_id][_debtor] += score;
            prizeScore[_id][_debtor] -= score;
            conditionOfFee[_debtor].score += score;
            claimedPercentage[_id][_debtor] += claimablePercentage;
            emit ScoreUpdated(_debtor, score);

            // 3) If the remaining supply is ≤ 50%, the debtor can claim up to a total of 50%
        } else if (
            _totalSupply[_id] <= pact[_id].amount / 2 &&
            claimedPercentage[_id][_debtor] < 50
        ) {
            uint8 claimablePercentage = 50 - claimedPercentage[_id][_debtor];
            uint score = (totalPoints * claimablePercentage) / 100;
            prizeScoreAlreadyClaim[_id][_debtor] += score;
            prizeScore[_id][_debtor] -= score;
            conditionOfFee[_debtor].score += score;
            claimedPercentage[_id][_debtor] += claimablePercentage;
            emit ScoreUpdated(_debtor, score);
        }
    }

    /**
     * @dev Calculates and applies an issuance fee based on the debtor’s score.
     *      The fee is taken from the collateral amount `_amountCollateral` and deposited
     *      into the contract’s balance (`balanceContractFeesForToken`). The remainder
     *      is kept as collateral for the pact.
     *
     * Fee rates (in millesimal, i.e. “per thousand” or ‱):
     *  - score > 1,000,000 => 0.5% (5 millesimi)
     *  - 700,000 < score <= 1,000,000 => 1.5% (15 millesimi)
     *  - 500,000 < score <= 700,000 => 3% (30 millesimi)
     *  - score <= 500,000 => 5% (50 millesimi)
     *
     * @param _iusser          The address of the debtor.
     * @param _tokenAddress    The ERC20 token used as collateral.
     * @param _amountCollateral The total collateral from which the fee is subtracted.
     * @return The actual fee amount deducted from `_amountCollateral`.
     */
    function _emisionPactFee(
        address _iusser,
        address _tokenAddress,
        uint _amountCollateral
    ) internal returns (uint) {
        uint score = conditionOfFee[_iusser].score;
        // High score, minimal fee
        if (score > 1000000) {
            return
                _updateBalanceContractForMintNewPact(
                    _tokenAddress,
                    _amountCollateral,
                    5
                ); // 0.5%
        }
        // Medium-high score
        if (score > 700000 && score <= 1000000) {
            return
                _updateBalanceContractForMintNewPact(
                    _tokenAddress,
                    _amountCollateral,
                    15
                ); // 1.5%
        }
        // Medium-low score
        if (score > 500000 && score <= 700000) {
            return
                _updateBalanceContractForMintNewPact(
                    _tokenAddress,
                    _amountCollateral,
                    30
                ); // 3%
        }
        // Low score
        if (score <= 500000) {
            return
                _updateBalanceContractForMintNewPact(
                    _tokenAddress,
                    _amountCollateral,
                    50
                ); // 5%
        }

        return 0;
    }

    /**
     * @dev Calculates and updates the contract’s fee balance during a new pact emission.
     *      1) Computes `(_amountCollateral * _fee) / 1000` as the actual fee to withhold.
     *      2) Increments `balanceContractFeesForToken[_tokenAddress]` by that amount.
     *      3) Emits `PaidFeeAtContract` event for transparency.
     *
     * @param _tokenAddress     The ERC20 token in which the fee is collected.
     * @param _amountCollateral The total collateral from which the fee is being deducted.
     * @param _fee              The fee rate in millesimal (e.g., 5 for 0.5%, 50 for 5%).
     * @return The actual fee amount after the division by 1000.
     */
    function _updateBalanceContractForMintNewPact(
        address _tokenAddress,
        uint _amountCollateral,
        uint16 _fee
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
     * @dev Calculates a liquidation fee during pact collateral liquidation based on
     *      the debtor’s score, deducting a percentage of `_amountCollateral` and
     *      transferring it to the contract’s fee balance.
     *
     * Fee tiers (in millesimal):
     *  - score > 1,000,000 => 0.5% (5 per 1000)
     *  - 700,000 < score <= 1,000,000 => 1.5% (15 per 1000)
     *  - 500,000 < score <= 700,000 => 3% (30 per 1000)
     *  - score <= 500,000 => 5% (50 per 1000)
     *
     * @param _iusser          The debtor’s address whose score determines the fee tier.
     * @param _tokenAddress    The ERC20 token used for collateral.
     * @param _amountCollateral The portion of collateral on which the fee is charged.
     * @return The actual fee amount deducted and added to the contract’s fee balance.
     */

    function _liquidationFee(
        address _iusser,
        address _tokenAddress,
        uint _amountCollateral
    ) internal returns (uint) {
        uint score = conditionOfFee[_iusser].score;

        if (score > 1000000) {
            return
                _updateBalanceContractForMintNewPact(
                    _tokenAddress,
                    _amountCollateral,
                    LIQUIDATION_FEE[0]
                );
        } else if (score > 700000) {
            // Implica che score <= 1000000
            return
                _updateBalanceContractForMintNewPact(
                    _tokenAddress,
                    _amountCollateral,
                    LIQUIDATION_FEE[1]
                );
        } else if (score > 500000) {
            // Implica che score <= 700000
            return
                _updateBalanceContractForMintNewPact(
                    _tokenAddress,
                    _amountCollateral,
                    LIQUIDATION_FEE[2]
                );
        } else {
            // score <= 500000
            return
                _updateBalanceContractForMintNewPact(
                    _tokenAddress,
                    _amountCollateral,
                    LIQUIDATION_FEE[3]
                );
        }
    }

    /**
     * @dev Applies a fixed scheduled reward fee of 0.5% (represented as 50 millesimal in `_upDateBalanceUserFees`)
     *      whenever a scheduled reward is paid out. This fee is added to the contract’s fee balance.
     *
     * @param _tokenAddress The ERC20 token in which the scheduled reward is paid.
     * @param _amount       The scheduled reward amount from which the fee is deducted.
     * @return The actual fee taken and added to `balanceContractFeesForToken`.
     */
    function _couponFee(
        address _tokenAddress,
        uint _amount
    ) internal returns (uint) {
        // A fixed 0.5% fee on each scheduled reward
        return _upDateBalanceUserFees(_tokenAddress, _amount, REWARD_FEE);
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
     * Pact: The return value currently uses a 0.5% figure `((_amount * 5) / 1000)`,
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
     * @dev Calculates the maximum possible interest amount for a given pact.
     * @param _id The pact ID for which the calculation is performed.
     * @return maxQtaInterest The total maximum interest that can be generated.
     *
     * Formula:
     * maxQtaInterest = (sizeLoan * (interest * number_of_coupons)) * totalSupply
     *
     * - `sizeLoan`: The loan amount for the pact.
     * - `interest`: Reward paid per scheduled reward.
     * - `rewardMaturity.length`: Total number of rewards.
     * - `totalSupply`: Total supply of pact tokens (ERC1155).
     *
     * This function provides the upper limit of the total interest payout if all pact tokens are held and all rewards are claimed.
     */
    function getMaxQtaInterest(uint _id) public view returns (uint) {
        uint maxQtaInterest = (pact[_id].sizeLoan +
            (pact[_id].interest * pact[_id].rewardMaturity.length)) *
            _totalSupply[_id];
        return maxQtaInterest;
    }

    /**
     * @dev Returns the remaining quantity of tokens that can still be deposited for interest payments.
     *
     * This function is particularly useful after the first deposit of interest tokens,
     * as the `maxInterestDeposit[_id]` value is only initialized at that moment.
     * Before the first deposit, calling this function will return `0` since the value
     * has not yet been calculated.
     *
     * @param _id The ID of the pact for which the remaining interest deposit is queried.
     * @return The remaining amount of tokens that can still be deposited for interest.
     */
    function getMissQtaInterest(uint _id) public view returns (uint) {
        return maxInterestDeposit[_id];
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
     * @dev Returns the current value of the incremental pact ID counter.
     *      This indicates the ID that will be assigned to the next created pact.
     */
    function viewPactID() public view returns (uint) {
        return pactId;
    }

    /**
     * @dev Returns the total supply of a specific pact identified by its token ID.
     * @param id The unique ID of the pact/token.
     */
    function totalSupply(uint256 id) public view returns (uint256) {
        return _totalSupply[id];
    }

    /**
     * @dev Returns the full details of a specific pact by its ID.
     * @param _id The unique ID of the pact.
     * @return Pact The full Pact struct containing all relevant data.
     */
    function showDeatailPactForId(uint _id) public view returns (Pact memory) {
        return pact[_id];
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
     * @dev Returns the current value of the scheduled reward fee.
     * @return The scheduled reward fee set in the contract.
     * @notice This function provides visibility into the current scheduled reward fee configuration.
     */
    function showCouponFee() external view returns (uint) {
        return REWARD_FEE;
    }

    /**
     * @dev Returns the current LIQUIDATION_FEE array.
     * @return An array containing the current liquidation fees.
     * @notice This function provides visibility into the current liquidation fee structure.
     */
    function showLiquidationFees() external view returns (uint16[4] memory) {
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
    ) external view returns (uint16[3] memory) {
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
