// SPDX-License-Identifier: Leluk911

pragma solidity ^0.8.24;

// Import statements for required libraries, interfaces, and contracts

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// Interface for ERC20 tokens, enabling interaction with standard ERC20 token functions.

import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
// Interface for ERC1155 tokens, allowing the contract to interact with multi-token standards.

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Library providing safe methods for ERC20 operations, protecting against reentrancy attacks.

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
// Utility contract that allows the contract owner to pause or unpause the contract for maintenance or security reasons.

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// Protects the contract against reentrancy attacks by preventing recursive calls to certain functions.

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// Provides ownership management, enabling the contract owner to perform privileged operations.

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
// Interface for contracts that handle ERC1155 token receipts.

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
// Standard for interface detection, allowing external systems to verify the supported interfaces of this contract.

import "./interface/Ibond.sol";
// Interface specific to the project's bond functionality, providing a standardized way to interact with bonds.

import {DownwardAuctionStorage} from "./DownwardAuctionStorage.sol";
// Storage contract that contains the state variables and mappings required for the DownwardAuction system.

import {console} from "hardhat/console.sol";

/**
 * @title DownwardAuction
 * @dev This contract implements the core logic for a downward auction system. It inherits from `DownwardAuctionStorage` for storage management,
 *      and integrates various utility contracts for ownership, pausability, reentrancy protection, and ERC1155 token handling.
 */
contract DownwardAuction is
    DownwardAuctionStorage, // Inherited storage structure for auction-related variables and mappings.
    ERC165, // ERC165 standard for interface detection.
    Pausable, // Provides mechanisms to pause and resume contract functions.
    ReentrancyGuard, // Protects against reentrancy attacks.
    Ownable, // Ensures only the owner can perform certain actions.
    IERC1155Receiver // Handles the receipt of ERC1155 tokens.
{
    /**
     * @dev Event emitted when a new auction is created.
     * @param _owner The address of the auction creator.
     * @param _id The unique identifier of the bond associated with the auction.
     * @param _amount The quantity of bonds being auctioned.
     * @notice Provides transparency for new auction creation, including the creator's address, bond ID, and amount.
     */
    event NewAuction(address indexed _owner, uint indexed _id, uint _amount);

    /**
     * @dev Event emitted when a participant makes a new installment in the auction pot.
     * @param _player The address of the participant who made the installment.
     * @param _index The index of the auction in the `auctions` array.
     * @param _amountPot The amount added to the pot by the participant.
     * @notice Tracks pot contributions made by participants in a specific auction, allowing monitoring of bid activity.
     */
    event newInstalmentPot(
        address indexed _player,
        uint indexed _index,
        uint _amountPot
    );

    /**
     * @dev Event emitted when an auction is closed, either by natural expiration or an emergency closure.
     * @param _index The index of the auction in the `auctions` array.
     * @param _time The timestamp when the auction was closed.
     * @notice Ensures clarity and transparency regarding the closure of auctions, including the time of closure.
     */
    event CloseAuction(uint _index, uint _time);

    /**
     * @dev Event emitted when a bond is withdrawn by its owner after an auction ends.
     * @param _user The address of the bond owner withdrawing their bond.
     * @param _index The index of the auction in the `auctions` array.
     * @param amount The amount of bonds withdrawn by the owner.
     * @notice Confirms the withdrawal of bonds by the rightful owner, including the auction index and bond amount.
     */
    event WithDrawBond(
        address indexed _user,
        uint indexed _index,
        uint indexed amount
    );

    /**
     * @dev Event emitted when a participant withdraws funds from their balance.
     * @param _user The address of the participant withdrawing the funds.
     * @param amount The amount of funds withdrawn.
     * @notice Tracks participant fund withdrawals to ensure transparency in fund management.
     */
    event WithDrawMoney(address indexed _user, uint indexed amount);

    /**
     * @dev Event emitted when a fee is successfully paid and added to the contract's balance.
     * @param _amount The amount of the fee paid.
     * @notice Allows monitoring of fees collected by the contract for auditing and reporting purposes.
     */
    event PaidFee(uint _amount);

    /**
     * @dev Event emitted when the tolerated discount of an auction is updated by the owner.
     * @param _index The index of the auction in the `auctions` array.
     * @param _newDiscount The updated tolerated discount value (in basis points).
     * @notice Captures changes to auction discount tolerance, providing transparency and ensuring proper tracking.
     */
    event ChangeTolleratedDiscount(uint indexed _index, uint _newDiscount);

    /**
     * @dev Event emitted when an auction is closed prematurely by the owner using emergency closure.
     * @param _owner The address of the auction owner triggering the emergency closure.
     * @param _index The index of the auction in the `auctions` array.
     * @notice Records emergency closures to identify and audit situations requiring immediate intervention.
     */
    event EmergencyCloseAuction(address indexed _owner, uint _index);

    /**
     * @dev Event emitted when a penalty fee is applied for exceeding the maximum number of penalties allowed in an auction.
     * @param _index The index of the auction in the `auctions` array.
     * @param feeAmount The penalty fee amount applied (in basis points).
     * @param timestamp The timestamp when the penalty was applied.
     * @notice Ensures transparency and accountability for penalty fees applied due to rule violations in auctions.
     */
    event OverPenaltyFeeApplied(
        uint indexed _index,
        uint feeAmount,
        uint timestamp
    );

    /**
     * @dev Event emitted when the bond contract address is updated.
     * @param previousAddress The previous address of the bond contract.
     * @param newAddress The new address of the bond contract.
     * @notice This event provides transparency regarding changes to the bond contract address,
     *         allowing external systems or users to track updates for security and auditing purposes.
     */
    event BondAddressUpdated(
        address indexed previousAddress,
        address indexed newAddress
    );

    /**
     * @dev Modifier to validate that the given auction index is within the bounds of the auctions array.
     * @param _index The index of the auction to validate.
     * @notice This ensures that the provided index is valid and prevents out-of-bounds errors when accessing the `auctions` array.
     *         If the condition is not met, the transaction reverts with a descriptive error message.
     */
    modifier outIndex(uint _index) {
        require(_index < auctions.length, "digit correct index for array");
        _;
    }

    /**
     * @dev Constructor for initializing the DownwardAuction contract.
     * @param _bondContrac The address of the ERC1155 bond contract associated with this auction.
     * @param _money The address of the ERC20 token used as the auction's currency (e.g., WETH or USDC).
     * @param _fixedFee The fixed fee amount applied to auction transactions below the price threshold.
     * @param _priceThreshold The price threshold above which a dynamic fee is applied.
     * @param _dinamicFee The dynamic fee percentage (in basis points) applied to auction transactions above the price threshold.
     * @notice This constructor initializes the bond contract, the auction currency, and the fee system.
     *         It also calls the `Ownable` constructor to set the deployer as the initial owner.
     */
    constructor(
        address _bondContrac,
        address _money,
        uint _fixedFee,
        uint _priceThreshold,
        uint _dinamicFee
    ) Ownable(msg.sender) {
        // Set the address of the ERC1155 bond contract
        bondContract = _bondContrac;

        // Set the address of the ERC20 token used as currency
        money = _money;

        // Initialize the fee system parameters
        feeSystem.fixedFee = _fixedFee;
        feeSystem.priceThreshold = _priceThreshold;
        feeSystem.dinamicFee = _dinamicFee;
    }

    /**
     * @dev Updates the address of the ERC1155 bond contract.
     * @param _bondContrac The new address of the bond contract.
     * @notice Only the owner of the contract can execute this function.
     *         The function ensures that the provided address is valid (non-zero) and emits an event
     *         to notify that the bond contract address has been updated.
     * Require The new bond contract address must not be the zero address.
     * Require The new bond contract address must be different from the current one.
     * @notice This function is protected by `nonReentrant` to prevent reentrancy attacks,
     *         even though it does not handle funds. This is an additional layer of security.
     */
    function setNewBondAddress(
        address _bondContrac
    ) external onlyOwner nonReentrant {
        require(_bondContrac != address(0), "Invalid contract address"); // Validates that the address is non-zero.
        require(
            _bondContrac != bondContract,
            "Address already set to this value"
        ); // Ensures the new address is not the same as the current one.

        address previousAddress = bondContract; // Stores the current address before updating.
        bondContract = _bondContrac; // Updates the bond contract address.

        emit BondAddressUpdated(previousAddress, _bondContrac); // Emits an event to log the update.
    }

    /**
     * @dev Allows the owner to set or update the address of the money token (ERC20).
     *      This function can only be called by the contract owner and ensures reentrancy protection.
     * @param _money The address of the new money token (e.g., USDC, WETH).
     * @notice Ensure the provided address is valid and not the zero address before calling this function.
     */
    function setNewMoneyToken(address _money) external onlyOwner nonReentrant {
        require(_money != address(0), "Invalid token address"); // Validates the new token address.
        money = _money; // Updates the money token address.
    }

    /**
     * @dev Allows the owner to set or update the fee system parameters.
     *      The fee system includes a fixed fee, a price threshold, and a dynamic fee.
     *      This function can only be called by the contract owner and ensures reentrancy protection.
     * @param _fixedFee The fixed fee amount to be applied below the price threshold.
     * @param _priceThreshold The price threshold at which the dynamic fee is applied.
     * @param _dinamicFee The dynamic fee rate (in basis points, where 10000 = 100%).
     */
    function setFeeSystem(
        uint _fixedFee,
        uint _priceThreshold,
        uint _dinamicFee
    ) external onlyOwner nonReentrant {
        require(_dinamicFee <= 10000, "Dynamic fee cannot exceed 100%"); // Validates dynamic fee.
        feeSystem.fixedFee = _fixedFee; // Updates the fixed fee.
        feeSystem.priceThreshold = _priceThreshold; // Updates the price threshold.
        feeSystem.dinamicFee = _dinamicFee; // Updates the dynamic fee.
    }

    /**
     * @dev Sets the fee tiers for the seller in the auction.
     * @param _echelons An array of price thresholds for applying different fee tiers.
     * @param _fees An array of corresponding fees (in basis points) for each echelon.
     * @notice Only the contract owner can call this function.
     * @notice `_echelons` and `_fees` arrays must have the same length, and the echelons must be in ascending order.
     */
    function setFeeSeller(
        uint[] memory _echelons,
        uint[] memory _fees
    ) external virtual onlyOwner {
        feeSeller.echelons = _echelons; // Set the price thresholds
        feeSeller.fees = _fees; // Set the corresponding fees
    }

    /**
     * @dev Creates a new auction bond.
     * @param _id The unique identifier of the bond.
     * @param _amount The quantity of bonds to be auctioned.
     * @param _startPrice The starting price for the auction.
     * @param _expired The expiration timestamp for the auction.
     * @param _tolleratedDiscount The maximum discount (in basis points) tolerated in the auction.
     * @notice The bond amount and starting price must be greater than 0.
     * @notice The expiration time must be at least `minPeriodAuction` in the future.
     * @notice The tolerated discount cannot exceed 10000 basis points (100%).
     * @notice This function can only be called when the contract is not paused.
     */
    function newAcutionBond(
        uint _id,
        uint _amount,
        uint _startPrice,
        uint _expired,
        uint _tolleratedDiscount
    ) external virtual nonReentrant whenNotPaused {
        require(_amount > 0, "Set correct bond's amount"); // Validate bond amount
        require(_startPrice > 0, "Set correct start price"); // Validate starting price
        require(
            _expired > (block.timestamp + minPeriodAuction),
            "Set correct expired period"
        ); // Validate auction expiration
        require(
            _tolleratedDiscount <= 10000,
            "set correct tolleranze discount"
        ); // Validate tolerated discount
        _newAcutionBond(
            msg.sender, // Auction creator
            _id, // Bond ID
            _amount, // Bond amount
            _startPrice, // Starting price
            _expired, // Expiration timestamp
            _tolleratedDiscount // Tolerated discount
        );
    }

    /**
     * @dev Places a new bid in the auction by adding funds to the pot.
     * @param _index The index of the auction in the array.
     * @param _amount The amount to be added to the auction pot.
     * @notice This function can only be called when the contract is not paused.
     * @notice `_amount` must be greater than zero and meet the auction's requirements.
     * Emits `newInstalmentPot` with the player's address, auction index, and bid amount.
     */
    function instalmentPot(
        uint _index,
        uint _amount
    ) external virtual nonReentrant whenNotPaused outIndex(_index) {
        _instalmentPot(msg.sender, _index, _amount);
        emit newInstalmentPot(msg.sender, _index, _amount); // Emit event for new pot instalment
    }

    /**
     * @dev Closes the auction once it has expired or conditions are met.
     * @param _index The index of the auction to be closed.
     * @notice This function can only be called when the contract is not paused.
     * Emits `CloseAuction` with the auction index and the timestamp of closure.
     */
    function closeAuction(
        uint _index
    ) external virtual nonReentrant whenNotPaused outIndex(_index) {
        _closeAuction(msg.sender, _index);
        emit CloseAuction(_index, block.timestamp); // Emit event for auction closure
    }

    /**
     * @dev Withdraws the bond from a closed auction.
     * @param _index The index of the auction to withdraw the bond from.
     * @notice This function can only be called when the contract is not paused.
     */
    function withDrawBond(
        uint _index
    ) external virtual nonReentrant whenNotPaused outIndex(_index) {
        _withDrawBond(msg.sender, _index);
    }

    /**
     * @dev Withdraws funds from the user's balance.
     * @param _amount The amount to be withdrawn by the user.
     * @notice This function can only be called when the contract is not paused.
     * Emits `WithDrawMoney` with the user's address and the withdrawn amount.
     */
    function withdrawMoney(
        uint _amount
    ) external virtual nonReentrant whenNotPaused {
        _withdrawMoney(msg.sender, _amount);
        emit WithDrawMoney(msg.sender, _amount); // Emit event for money withdrawal
    }

    /**
     * @dev Updates the tolerated discount for an active auction.
     * @param _index The index of the auction in the array.
     * @param _newDiscount The new tolerated discount percentage.
     * @notice Only the owner of the auction can update the discount.
     * @notice This function can only be called when the contract is not paused.
     */
    function changeTolleratedDiscount(
        uint _index,
        uint _newDiscount
    ) external nonReentrant outIndex(_index) whenNotPaused {
        _changeTolleratedDiscount(msg.sender, _index, _newDiscount);
    }

    /**
     * @dev Forces the emergency closure of an auction before expiration.
     * @param _index The index of the auction to be closed.
     * @notice This function can only be called by the auction owner when the contract is not paused.
     * @notice This is used for exceptional cases to avoid stalled or zombie auctions.
     */
    function emergencyCloseAuction(
        uint _index
    ) external nonReentrant outIndex(_index) whenNotPaused {
        _emergencyCloseAuction(msg.sender, _index);
    }

    /**
     * @dev Sets the cooldown period for making subsequent bids in an auction.
     * @param _coolDown The new cooldown period in seconds.
     * @notice Only the contract owner can update this value.
     */
    function setCoolDown(uint _coolDown) external virtual onlyOwner {
        coolDown = _coolDown;
    }

    /**
     * @dev Withdraws all accumulated fees from the contract to the owner's wallet.
     * @notice Only the contract owner can withdraw the fees.
     * @notice This function transfers all available fees in the contract balance to the owner's address.
     */
    function withdrawFees() external virtual onlyOwner {
        uint amount = contractBalance; // Get the current contract balance
        contractBalance = 0; // Reset the contract balance to zero
        SafeERC20.safeTransfer(IERC20(money), owner(), amount); // Transfer fees to the owner
    }

    /**
     * @dev Initializes a new auction for a specific bond.
     * @param _user The address of the user creating the auction.
     * @param _id The unique ID of the bond being auctioned.
     * @param _amount The amount of bonds to be auctioned.
     * @param _startPrice The starting price for the auction.
     * @param _expired The expiration timestamp for the auction.
     * @param _tolleratedDiscount The maximum discount tolerated during the auction.
     * @notice This function transfers the specified bond amount to the contract and sets up the auction data.
     */
    function _newAcutionBond(
        address _user,
        uint _id,
        uint _amount,
        uint _startPrice,
        uint _expired,
        uint _tolleratedDiscount
    ) internal virtual {
        _depositBond(_user, address(this), _id, _amount); // Transfer the bond to the contract
        _setAuctionData(
            _user,
            _id,
            _amount,
            _startPrice,
            _expired,
            _tolleratedDiscount
        ); // Set up the auction data
    }

    /**
     * @dev Transfers a specified amount of bonds from a user to a target address.
     * @param _user The address of the bond owner.
     * @param _to The target address to receive the bond.
     * @param _id The unique ID of the bond being transferred.
     * @param _amount The amount of bonds to be transferred.
     * @notice Uses the ERC1155 `safeTransferFrom` function to ensure a secure transfer.
     */
    function _depositBond(
        address _user,
        address _to,
        uint _id,
        uint _amount
    ) internal virtual {
        IERC1155(bondContract).safeTransferFrom(_user, _to, _id, _amount, ""); // Transfer bonds securely
    }

    /**
     * @dev Sets the data for a new auction and stores it in the `auctions` array.
     * @param _owner The address of the auction creator.
     * @param _id The unique ID of the bond being auctioned.
     * @param _amount The amount of bonds to be auctioned.
     * @param _startPrice The starting price for the auction.
     * @param _expired The expiration timestamp for the auction.
     * @param _tolleratedDiscount The maximum discount tolerated during the auction.
     * @notice Creates an `Auction` struct with the provided parameters and pushes it to the `auctions` array.
     *         Emits a `NewAuction` event upon successful creation.
     */
    function _setAuctionData(
        address _owner,
        uint _id,
        uint _amount,
        uint _startPrice,
        uint _expired,
        uint _tolleratedDiscount
    ) internal virtual {
        uint[] memory _penality; // Initialize an empty penalty array
        Auction memory _auction = Auction(
            _owner, // Auction creator
            _id, // Bond ID
            _amount, // Bond amount
            _startPrice, // Starting price
            _expired, // Expiration timestamp
            0, // Initial pot (set to zero)
            _owner, // Initial player (set to owner)
            true, // Auction is open
            _tolleratedDiscount, // Discount tolerance
            _penality // Empty penalty array
        );
        auctions.push(_auction); // Store the auction in the array
        emit NewAuction(_owner, _id, _amount); // Emit event for auction creation
    }

    /**
     * @dev Handles the placement of a new pot by a player in the auction.
     * @param _player The address of the player placing the new pot.
     * @param _index The index of the auction in the `auctions` array.
     * @param _amount The amount of tokens being added to the pot.
     * @notice Ensures the auction is still active, the player is not the auction owner,
     *         and the new pot respects the auction's discount tolerance and rules.
     *         Locks the new player's funds and unlocks the previous player's funds.
     */
    function _instalmentPot(
        address _player,
        uint _index,
        uint _amount
    ) internal virtual {
        // Ensure the auction is not expired
        require(
            auctions[_index].expired > block.timestamp,
            "This auction is expired"
        );
        // Ensure the auction is open
        require(auctions[_index].open == true, "This auction is close");

        // Check that the new pot respects the auction rules
        _checkPot(
            _index,
            auctions[_index].pot,
            _calcPotFee(_amount),
            auctions[_index].tolleratedDiscount
        );

        // Ensure the player is not the auction owner
        require(auctions[_index].owner != _player, "Owner can't pot");

        // Enforce cooldown time between pot placements for the player
        coolDownControl(_player, _index);

        // Deposit the player's tokens into the contract
        _depositErc20(_player, address(this), _amount);

        // Calculate the pot amount after deducting fees
        uint amountLessFee = _paidPotFee(_amount);

        // Update the player's total balance and lock the new funds
        balanceUser[_player] += amountLessFee;
        _updateLockBalance(_player, amountLessFee, true);

        // Unlock the previous player's funds
        _updateLockBalance(
            auctions[_index].player,
            auctions[_index].pot,
            false
        );

        // Update the auction data with the new player and pot amount
        auctions[_index].player = _player;
        auctions[_index].pot = amountLessFee;
    }

    /**
     * @dev Updates the lock balance for a user by either increasing or decreasing it.
     *      Ensures that the operation does not result in inconsistencies in the user's balances.
     * @param _user The address of the user whose lock balance is being updated.
     * @param _amount The amount to add to or subtract from the lock balance.
     * @param isLock A boolean indicating the operation type:
     *               - `true` to increase (lock) the balance.
     *               - `false` to decrease (unlock) the balance.
     * @notice Ensures that the locked balance does not exceed the user's total balance when locking,
     *         and does not drop below zero when unlocking.
     */
    function _updateLockBalance(
        address _user,
        uint _amount,
        bool isLock
    ) internal {
        if (isLock) {
            // Increase the lock balance without exceeding the user's total balance
            require(
                lockBalance[_user] + _amount <= balanceUser[_user],
                "Insufficient free balance for locking"
            );
            lockBalance[_user] += _amount;
        } else {
            // Decrease the lock balance without going negative
            require(
                lockBalance[_user] >= _amount,
                "Insufficient locked balance"
            );
            lockBalance[_user] -= _amount;
        }
    }

    /**
     * @dev Calculates and deducts the pot fee from the provided amount, then updates the contract's fee balance.
     * @param _amount The amount to calculate and deduct fees from.
     * @return The remaining amount after the fee deduction.
     * @notice If the amount is below the `priceThreshold`, a fixed fee is applied.
     *         Otherwise, a dynamic fee based on basis points is applied.
     *         The deducted fee is added to the contract's fee balance.
     */
    function _paidPotFee(uint _amount) internal virtual returns (uint) {
        if (_amount < feeSystem.priceThreshold) {
            // Apply a fixed fee if the amount is below the price threshold
            contractBalance += feeSystem.fixedFee;
            emit PaidFee(_amount);
            return _amount - feeSystem.fixedFee;
        } else {
            // Apply a dynamic fee calculated using basis points if the amount is above the price threshold
            uint fee = calculateBasisPoints(_amount, feeSystem.dinamicFee);
            contractBalance += fee;
            emit PaidFee(_amount);
            return _amount - fee;
        }
    }

    /**
     * @dev Transfers ERC20 tokens from one address to another.
     * @param _from The address sending the tokens.
     * @param _to The address receiving the tokens.
     * @param _amount The amount of tokens to transfer.
     * @notice Uses the SafeERC20 library to ensure secure token transfers.
     */
    function _depositErc20(
        address _from,
        address _to,
        uint _amount
    ) internal virtual {
        SafeERC20.safeTransferFrom(IERC20(money), _from, _to, _amount);
    }

    /**
     * @dev Updates the tolerated discount of an auction and applies penalties based on auction state.
     * @param _owner The address of the auction owner requesting the change.
     * @param _index The index of the auction in the `auctions` array.
     * @param _newDiscount The new tolerated discount value.
     * @notice This function ensures that the new discount is greater than the current one and within valid limits.
     *         If the maximum number of penalties is reached, an over-penalty fee is applied.
     */
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
        require(_newDiscount <= 1000, "Set correct discount");
        require(
            auctions[_index].tolleratedDiscount < _newDiscount,
            "New discount must be greater than the current discount"
        );

        if (auctions[_index].penality.length == MAX_PENALTY_ENTRIES) {
            auctions[_index].penality.push(OVER_PENALTY_FEE_PERCENTAGE);
            emit OverPenaltyFeeApplied(
                _index,
                OVER_PENALTY_FEE_PERCENTAGE,
                block.timestamp
            );
        } else if (auctions[_index].penality.length > MAX_PENALTY_ENTRIES) {
            revert("Reached limit of change and penalty");
        }

        if (auctions[_index].expired - block.timestamp >= 1 days) {
            // Add a penalty of 5% for changes made more than 1 day before expiration
            auctions[_index].penality.push(500);
        } else if (
            auctions[_index].expired - block.timestamp < 1 days &&
            auctions[_index].expired - block.timestamp >= 1 hours
        ) {
            // Add a penalty of 8% for changes made between 1 day and 1 hour before expiration
            auctions[_index].penality.push(800);
        } else {
            // Add a penalty of 10% for changes made less than 1 hour before expiration
            auctions[_index].penality.push(1000);
        }
        auctions[_index].tolleratedDiscount = _newDiscount;
        emit ChangeTolleratedDiscount(_index, _newDiscount);
    }

    /**
     * @dev Handles the emergency closure of an auction by the owner, applying penalties if necessary.
     * @param _owner The address of the auction owner requesting the emergency closure.
     * @param _index The index of the auction in the `auctions` array.
     * @notice This function ensures that the auction is still open and applies penalties depending on the time remaining.
     *         If the maximum number of penalties is reached, an over-penalty fee is applied.
     */
    function _emergencyCloseAuction(address _owner, uint _index) internal {
        require(
            auctions[_index].expired > block.timestamp,
            "This auction is expired"
        );
        require(_owner == auctions[_index].owner, "Not Owner");
        require(auctions[_index].open == true, "This auction already close");

        if (auctions[_index].penality.length == MAX_PENALTY_ENTRIES) {
            auctions[_index].penality.push(OVER_PENALTY_FEE_PERCENTAGE);
            emit OverPenaltyFeeApplied(
                _index,
                OVER_PENALTY_FEE_PERCENTAGE,
                block.timestamp
            );
        } else if (auctions[_index].penality.length > MAX_PENALTY_ENTRIES) {
            _closeAuctionOperation(_index);
            emit EmergencyCloseAuction(msg.sender, _index);
        }

        auctions[_index].open = false;
        if (auctions[_index].expired - block.timestamp >= 1 days) {
            // Add a penalty of 15% for emergency closure more than 1 day before expiration
            auctions[_index].penality.push(1500);
        } else {
            // Add a penalty of 20% for emergency closure less than 1 day before expiration
            auctions[_index].penality.push(2000);
        }
        _closeAuctionOperation(_index);
        emit EmergencyCloseAuction(msg.sender, _index);
    }

    /**
     * @dev Closes an auction and finalizes its operations.
     * @param _owner The address initiating the auction closure.
     * @param _index The index of the auction in the `auctions` array.
     * @notice Ensures the auction is expired, still open, and that the caller has the appropriate permissions.
     *         Once validated, it proceeds to finalize the auction by redistributing funds and penalizing if needed.
     */
    function _closeAuction(address _owner, uint _index) internal virtual {
        require(
            auctions[_index].expired < block.timestamp,
            "This auction is not expired"
        );
        require(
            _owner == auctions[_index].owner ||
                _owner == auctions[_index].player ||
                _owner == owner(), // Allows the contract owner to force-close the auction to collect fees.
            "Not Owner"
        );
        require(auctions[_index].open == true, "This auction already closed");
        auctions[_index].open = false;
        _closeAuctionOperation(_index);
    }

    /**
     * @dev Finalizes the auction closure process by redistributing the pot and applying penalties.
     * @param _index The index of the auction in the `auctions` array.
     * @notice Penalties are applied iteratively, and fees are deducted from the remaining pot.
     *         If the pot reaches zero during penalties, the process halts early.
     */
    function _closeAuctionOperation(uint _index) internal {
        address newOwner = auctions[_index].player;
        address oldOwner = auctions[_index].owner;

        // Apply penalties to the pot
        uint initialPot = auctions[_index].pot;
        uint pot = auctions[_index].pot;
        for (uint i = 0; i < auctions[_index].penality.length; i++) {
            if (pot == 0) {
                break; // Stop further penalty application if the pot is empty
            }
            pot = _paidPenalityFees(pot, auctions[_index].penality[i]);
        }

        // Deduct the seller's fee if there is remaining pot
        if (pot > 0) {
            pot = _paidSellFee(pot);
        }

        // Reset auction pot and transfer ownership to the winning player
        auctions[_index].pot = 0;
        auctions[_index].owner = newOwner;

        // Adjust the balance and locked funds of the participants
        balanceUser[newOwner] -= initialPot;
        _updateLockBalance(newOwner, initialPot, false); // Unlock funds for the new owner
        balanceUser[oldOwner] += pot;
    }

    /**
     * @dev Calculates and deducts penalty fees from a given amount.
     * @param _amount The amount from which the penalty fee is to be deducted.
     * @param _penality The penalty percentage in basis points (e.g., 500 for 5%).
     * @return The remaining amount after the penalty fee is deducted.
     * @notice The deducted fee is added to the contract's balance.
     */
    function _paidPenalityFees(
        uint _amount,
        uint _penality
    ) internal returns (uint) {
        uint fee = calculateBasisPoints(_amount, _penality);
        contractBalance += fee;
        return _amount - fee;
    }

    /**
     * @dev Calculates and deducts the seller fee based on the amount.
     * @param _amount The amount from which the seller fee is to be deducted.
     * @return The remaining amount after deducting the seller fee.
     * @notice The deducted fee is added to the contract's balance.
     *         Different fee tiers are applied based on the amount thresholds.
     */
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

    /**
     * @dev Withdraws bonds from the contract after the auction ends.
     * @param _owner The address of the bond owner requesting the withdrawal.
     * @param _index The index of the auction in the `auctions` array.
     * @notice Ensures the auction is closed and the caller is the owner.
     *         Transfers the bond amount back to the owner.
     */
    function _withDrawBond(address _owner, uint _index) internal virtual {
        require(_owner == auctions[_index].owner, "Not Owner");
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

    /**
     * @dev Withdraws money (ERC20 tokens) from the user's balance.
     * @param _user The address of the user requesting the withdrawal.
     * @param _amount The amount of tokens to withdraw.
     * @notice Ensures the user has sufficient free balance and does not exceed locked funds.
     *         Safely transfers the requested amount to the user.
     */
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

        require(
            lockBalance[_user] <= balanceUser[_user],
            "Locked balance exceeds total balance after withdrawal"
        );

        SafeERC20.safeTransfer(IERC20(money), _user, _amount);
    }

    /**
     * @dev Enforces a cooldown period for a user before allowing further actions.
     * @param _user The address of the user to enforce cooldown for.
     * @param _id The ID of the auction associated with the user's action.
     * @notice Ensures that a user cannot place another bid within the cooldown period.
     *         Updates the timestamp of the last action for the specified auction and user.
     */
    function coolDownControl(address _user, uint _id) internal virtual {
        require(
            lastPotTime[_user][_id] + coolDown < block.timestamp,
            "Wait for pot again"
        );
        lastPotTime[_user][_id] = block.timestamp;
    }

    /**
     * @dev Calculates the basis points of a given amount.
     * @param amount The amount on which the basis points are to be calculated.
     * @param bps The basis points (e.g., 100 = 1%, 10000 = 100%).
     * @return The value representing the basis points of the given amount.
     * @notice This function simplifies percentage calculations in the contract.
     */
    function calculateBasisPoints(
        uint256 amount,
        uint256 bps
    ) internal pure virtual returns (uint) {
        return (amount * bps) / 10000; // 10000 bps = 100%
    }

    /**
     * @dev Handles the receipt of a single ERC1155 token type.
     * @param operator The address which initiated the transfer (e.g., msg.sender).
     * @param from The address which previously owned the token.
     * @param id The ID of the token being transferred.
     * @param value The amount of tokens being transferred.
     * @param data Additional data with no specified format.
     * @return The selector for this function to signal successful receipt of the token.
     * @notice Override this function to implement custom logic for single token transfers, if necessary.
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure override returns (bytes4) {
        // Custom logic can be added here if necessary
        return this.onERC1155Received.selector;
    }

    /**
     * @dev Handles the receipt of multiple ERC1155 token types in a batch.
     * @param operator The address which initiated the transfer (e.g., msg.sender).
     * @param from The address which previously owned the tokens.
     * @param ids An array containing IDs of each token being transferred.
     * @param values An array containing amounts of each token being transferred.
     * @param data Additional data with no specified format.
     * @return The selector for this function to signal successful receipt of the batch.
     * @notice Override this function to implement custom logic for batch token transfers, if necessary.
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure override returns (bytes4) {
        // Custom logic can be added here if necessary
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev Returns the free balance of a user, which includes both locked and unlocked funds.
     * @param _user The address of the user whose free balance is being queried.
     * @return The total balance of the user.
     * @notice This includes the locked portion of the balance.
     */
    function showUserBalanceFree(
        address _user
    ) public view virtual returns (uint) {
        return balanceUser[_user];
    }

    /**
     * @dev Returns the locked balance of a user, which represents the funds that are temporarily unavailable.
     * @param _user The address of the user whose locked balance is being queried.
     * @return The locked balance of the user.
     */
    function showUserBalanceLock(
        address _user
    ) public view virtual returns (uint) {
        return lockBalance[_user];
    }

    /**
     * @dev Returns the list of penalties associated with a specific auction.
     * @param _index The index of the auction in the array.
     * @return An array of penalties applied to the auction.
     */
    function showAuctionPenalityes(
        uint _index
    ) external view returns (uint[] memory) {
        return auctions[_index].penality;
    }

    /**
     * @dev Returns the current fee system configuration.
     * @return A struct containing fixed fee, price threshold, and dynamic fee settings.
     */
    function showFeesSystem() public view virtual returns (FeeSystem memory) {
        return feeSystem;
    }

    /**
     * @dev Returns the seller fee structure.
     * @return A struct containing echelons and their associated fees.
     */
    function showFeesSeller() public view virtual returns (FeeSeller memory) {
        return feeSeller;
    }

    /**
     * @dev Returns the total contract balance accumulated from fees.
     * @return The current balance of the contract.
     */
    function showBalanceFee() external view virtual returns (uint) {
        return contractBalance;
    }

    /**
     * @dev Returns the complete list of auctions.
     * @return An array of all auction structs.
     */
    function showAuctionsList() public view virtual returns (Auction[] memory) {
        return auctions;
    }

    /**
     * @dev Returns the details of a specific auction.
     * @param _index The index of the auction in the array.
     * @return The Auction struct corresponding to the provided index.
     */
    function showAuction(
        uint _index
    ) public view virtual returns (Auction memory) {
        return auctions[_index];
    }

    /**
     * @dev Validates the pot amount for a bid in the auction.
     *      Ensures the bid complies with the auction's rules for minimum accepted value and tolerated discount.
     * @param _index The index of the auction in the array.
     * @param _pot The current pot value of the auction.
     * @param _amount The new bid amount to be validated.
     * @param _tolleratedDiscount The maximum discount percentage tolerated for the bid.
     * @notice Reverts if the bid does not comply with the auction's rules.
     */
    function _checkPot(
        uint _index,
        uint _pot,
        uint _amount,
        uint _tolleratedDiscount
    ) internal view {
        if (_pot > 0) {
            require(_pot > _amount, "This pot is higher than the current pot.");
            require(
                _amount >=
                    _pot - calculateBasisPoints(_pot, _tolleratedDiscount),
                "This pot is lower than the tolerated discount."
            );
        } else {
            require(
                auctions[_index].startPrice > _amount,
                "This pot is higher than the starting price."
            );
            require(
                _amount >=
                    auctions[_index].startPrice -
                        calculateBasisPoints(
                            auctions[_index].startPrice,
                            _tolleratedDiscount
                        ),
                "This pot is lower than the tolerated discount."
            );
        }
    }

    /**
     * @dev Calculates the remaining amount after deducting applicable pot fees.
     *      Fees can be either fixed or dynamic, based on the bid amount and fee system configuration.
     * @param _amount The amount to calculate fees for.
     * @return The net amount after deducting the applicable fee.
     */
    function _calcPotFee(uint _amount) internal view virtual returns (uint) {
        if (_amount < feeSystem.priceThreshold) {
            return _amount - feeSystem.fixedFee;
        } else {
            return
                _amount - calculateBasisPoints(_amount, feeSystem.dinamicFee);
        }
    }


    /**
     * @dev Returns the address of the bond contract.
     * @return The address of the bond contract currently set in the system.
     * @notice This function provides visibility into the bond contract address
     *         for external users or systems interacting with the contract.
     */
    function showBondContractAddress() public view returns (address) {
        return bondContract;
    }
}
