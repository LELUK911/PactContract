// SPDX-License-Identifier: Leluk911

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// Provides the interface for ERC20 tokens, enabling the contract to interact with standard ERC20 token functions
// such as `transfer`, `approve`, `transferFrom`, and querying balances.

import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
// Provides the interface for ERC1155 tokens, allowing the contract to interact with multi-token standards.
// This is useful for operations like transferring multiple types of tokens in a single transaction.

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// A library that ensures safe interaction with ERC20 tokens, protecting against reentrancy attacks and unexpected
// token behavior by wrapping `transfer` and `transferFrom` calls with additional checks.

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
// Adds the ability to pause and unpause the contract by the owner or an authorized entity.
// This is useful for temporarily disabling certain functions in case of an emergency or for maintenance purposes.

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// Provides protection against reentrancy attacks by ensuring that a function cannot be re-entered
// while it is already executing. This is critical for securing contract logic that handles external calls.

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// Implements basic ownership functionality, allowing only the contract owner to execute specific functions.
// Useful for managing privileged actions such as updating configurations or withdrawing fees.

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
// Defines the interface for contracts that are intended to handle the receipt of ERC1155 tokens.
// This is essential for contracts that need to safely receive or manage ERC1155 token transfers.

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
// Implements the ERC165 standard for interface detection. This allows the contract to declare which
// interfaces it supports, enabling other contracts and systems to query this information.

import "./interface/Ibond.sol";
// Custom interface specific to the project's bond functionality, providing a standardized way
// for the contract to interact with bond-related operations or logic unique to this system.

import {UpwardAuctionStorage} from "./UpwardAuctionStorage.sol";
// Storage contract that contains the state variables and mappings required for the DownwardAuction system.

//import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
//import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
//import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
//import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {console} from "hardhat/console.sol";

contract UpwardAuction is
    UpwardAuctionStorage,
    Pausable, // Allows the contract to be paused and unpaused by the owner.
    ReentrancyGuard, // Prevents reentrancy attacks in critical functions.
    Ownable
{
    /**
     * @dev Emitted when a new auction is created.
     * @param _owner Address of the user who created the auction.
     * @param _id Unique identifier of the bond being auctioned.
     * @param _amount Number of bond units being auctioned.
     */
    event NewAuction(address indexed _owner, uint indexed _id, uint _amount);

    /**
     * @dev Emitted when a new bid (instalment) is placed on an auction pot.
     * @param _player Address of the user placing the bid.
     * @param _index Index of the auction in the list.
     * @param _amountPot Amount of the new pot after the bid.
     */
    event newInstalmentPot(
        address indexed _player,
        uint indexed _index,
        uint _amountPot
    );

    /**
     * @dev Emitted when an auction is closed.
     * @param _index Index of the auction in the list.
     * @param _time Timestamp when the auction was closed.
     */
    event CloseAuction(uint _index, uint _time);

    /**
     * @dev Emitted when a user withdraws bonds after an auction.
     * @param _user Address of the user withdrawing the bonds.
     * @param _index Index of the auction in the list.
     * @param amount Number of bond units withdrawn.
     */
    event WithDrawBond(
        address indexed _user,
        uint indexed _index,
        uint indexed amount
    );

    /**
     * @dev Emitted when a user withdraws money from their balance.
     * @param _user Address of the user withdrawing the money.
     * @param amount Amount of money withdrawn.
     */
    event WithDrawMoney(address indexed _user, uint indexed amount);

    /**
     * @dev Emitted when a fee is paid during the auction process.
     * @param _amount Amount of the fee paid.
     */
    event PaidFee(uint _amount);

    /**
     * @dev Emitted when the owner withdraws accumulated fees from the contract.
     * @param owner Address of the contract owner.
     * @param amount Amount of fees withdrawn.
     * @param timestamp Timestamp when the withdrawal occurred.
     */
    event FeesWithdrawn(address indexed owner, uint amount, uint timestamp);

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
     * @dev Modifier to ensure the provided index is within the bounds of the auctions array.
     *      Reverts if the index is out of bounds.
     * @param _index The index of the auction to validate.
     */
    modifier outIndex(uint _index) {
        require(_index < auctions.length, "digit correct index for array");
        _;
    }

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

    /*

    function initialize(
        address _owner,
        address _bondContrac,
        address _money,
        uint _fixedFee,
        uint _priceThreshold,
        uint _dinamicFee
    ) public initializer {
        __Ownable_init(); // Initializes the OwnableUpgradeable contract to handle ownership.
        transferOwnership(_owner); // Transfers ownership to the specified owner address.
        bondContract = _bondContrac;
        money = _money;

        feeSystem.fixedFee = _fixedFee;
        feeSystem.priceThreshold = _priceThreshold;
        feeSystem.dinamicFee = _dinamicFee;
    }
    */

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
     * @dev Sets the fee structure for sellers.
     *      Updates the echelons and fees based on the provided arrays.
     *      Ensures that the arrays have matching lengths and that echelons are in ascending order.
     * @param _echelons An array of price thresholds defining the echelons.
     * @param _fees An array of fee percentages corresponding to each echelon.
     */
    function setFeeSeller(
        uint[] memory _echelons,
        uint[] memory _fees
    ) external virtual onlyOwner nonReentrant {
        require(
            _echelons.length == _fees.length,
            "Echelons and fees length mismatch"
        );
        for (uint i = 1; i < _echelons.length; i++) {
            require(
                _echelons[i] > _echelons[i - 1],
                "Echelons must be in ascending order"
            );
        }
        feeSeller.echelons = _echelons;
        feeSeller.fees = _fees;
    }

    /**
     * @dev Creates a new auction for bonds.
     *      Validates the bond's amount, starting price, and expiration period before proceeding.
     * @param _id The ID of the bond being auctioned.
     * @param _amount The number of bonds to include in the auction.
     * @param _startPrice The initial price for the auction.
     * @param _expired The expiration timestamp of the auction.
     */
    function newAcutionBond(
        uint _id,
        uint _amount,
        uint _startPrice,
        uint _expired
    ) external virtual nonReentrant whenNotPaused {
        require(_amount > 0, "Set correct bond's amount");
        require(_startPrice > 0, "Set correct start price");
        require(
            _expired > (block.timestamp + minPeriodAuction),
            "Set correct expired period"
        );
        _newAcutionBond(msg.sender, _id, _amount, _startPrice, _expired);
    }

    /**
     * @dev Places an installment on the pot for a specific auction.
     *      Ensures the auction is active and the index is valid.
     * @param _index The index of the auction being targeted.
     * @param _amount The amount being added to the pot.
     */
    function instalmentPot(
        uint _index,
        uint _amount
    ) external virtual nonReentrant whenNotPaused outIndex(_index) {
        _instalmentPot(msg.sender, _index, _amount);
        emit newInstalmentPot(msg.sender, _index, _amount);
    }

    /**
     * @dev Closes an active auction.
     *      Ensures the auction is eligible for closure and emits a `CloseAuction` event.
     * @param _index The index of the auction to close.
     * @notice Only the auction owner, the current highest bidder, or the contract owner can close the auction.
     */
    function closeAuction(
        uint _index
    ) external virtual nonReentrant whenNotPaused outIndex(_index) {
        _closeAuction(msg.sender, _index);
        emit CloseAuction(_index, block.timestamp);
    }

    /**
     * @dev Withdraws bonds from a closed auction.
     *      Ensures the auction is closed and the caller is the auction owner.
     * @param _index The index of the auction from which bonds are withdrawn.
     * @notice Bonds can only be withdrawn after the auction has expired and is no longer active.
     */
    function withDrawBond(
        uint _index
    ) external virtual nonReentrant whenNotPaused outIndex(_index) {
        _withDrawBond(msg.sender, _index);
    }

    /**
     * @dev Withdraws available funds from the contract.
     *      Ensures the user has sufficient free balance (not locked) before processing the withdrawal.
     * @param _amount The amount of funds to withdraw.
     * @notice The function will emit a `WithDrawMoney` event upon successful withdrawal.
     */
    function withdrawMoney(
        uint _amount
    ) external virtual nonReentrant whenNotPaused {
        _withdrawMoney(msg.sender, _amount);
        emit WithDrawMoney(msg.sender, _amount);
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
     * @dev Sets the cooldown period for user actions (e.g., placing bids).
     *      This function can only be called by the contract owner.
     * @param _coolDown The cooldown period to set, in seconds.
     * @notice The cooldown is used to prevent rapid consecutive actions from the same user.
     */
    function setCoolDown(uint _coolDown) external virtual onlyOwner {
        coolDown = _coolDown;
    }

    /**
     * @dev Allows the contract owner to withdraw accumulated fees.
     *      Transfers the contract's fee balance to the owner's address.
     * @notice Emits a `FeesWithdrawn` event with the withdrawn amount and timestamp.
     * Require The contract must have a positive balance of fees to withdraw.
     */
    function withdrawFees() external virtual onlyOwner {
        uint amount = contractBalance;
        require(amount > 0, "No fees available to withdraw"); // Ensure there are fees to withdraw
        contractBalance = 0; // Reset the contract balance to zero
        SafeERC20.safeTransfer(IERC20(money), owner(), amount); // Transfer the fees to the owner
        emit FeesWithdrawn(owner(), amount, block.timestamp); // Emit event for transparency
    }

    /**
     * @dev Creates a new auction for a bond.
     *      Transfers the specified bond amount from the user to the contract
     *      and initializes the auction data.
     * @param _user Address of the user creating the auction.
     * @param _id ID of the bond being auctioned.
     * @param _amount Number of bond units being auctioned.
     * @param _startPrice Starting price of the auction.
     * @param _expired Expiration timestamp of the auction.
     * @notice This function is called internally when a new auction is created.
     */
    function _newAcutionBond(
        address _user,
        uint _id,
        uint _amount,
        uint _startPrice,
        uint _expired
    ) internal virtual {
        _depositBond(_user, address(this), _id, _amount); // Transfer bond to the contract
        _setAuctionData(_user, _id, _amount, _startPrice, _expired); // Initialize auction data
    }

    /**
     * @dev Transfers bond tokens from a user to the contract.
     *      Uses the ERC1155 `safeTransferFrom` method to securely transfer tokens.
     * @param _user Address of the user transferring the bond.
     * @param _to Address of the recipient (contract).
     * @param _id ID of the bond being transferred.
     * @param _amount Number of bond units being transferred.
     * @notice This function ensures the transfer of bond tokens to the contract.
     */
    function _depositBond(
        address _user,
        address _to,
        uint _id,
        uint _amount
    ) internal virtual {
        IERC1155(bondContract).safeTransferFrom(_user, _to, _id, _amount, ""); // Transfer bond tokens
    }

    /**
     * @dev Initializes the data for a new auction.
     *      Stores auction details and emits an event for the new auction.
     * @param _owner Address of the auction creator.
     * @param _id ID of the bond being auctioned.
     * @param _amount Number of bond units being auctioned.
     * @param _startPrice Starting price of the auction.
     * @param _expired Expiration timestamp of the auction.
     * @notice This function is called internally after the bond is transferred to the contract.
     */
    function _setAuctionData(
        address _owner,
        uint _id,
        uint _amount,
        uint _startPrice,
        uint _expired
    ) internal virtual {
        Auction memory _auction = Auction(
            _owner,
            _id,
            _amount,
            _startPrice,
            _expired,
            0, // Initial pot value
            _owner, // Initial player is the owner
            true // Auction is open
        );
        auctions.push(_auction); // Add the auction to the list
        emit NewAuction(_owner, _id, _amount); // Emit event for the new auction
    }

    /**
     * @dev Handles a user's bid (instalment) in an active auction.
     *      Updates the pot value and manages locked balances for players.
     * @param _player Address of the user placing the bid.
     * @param _index Index of the auction in the `auctions` array.
     * @param _amount Amount being bid by the user.
     * @notice Ensures that the bid meets all conditions before updating the auction state.
     */
    function _instalmentPot(
        address _player,
        uint _index,
        uint _amount
    ) internal virtual {
        require(
            auctions[_index].expired > block.timestamp,
            "This auction is expired"
        ); // Ensure the auction is not expired
        require(auctions[_index].open == true, "This auction is close"); // Ensure the auction is open
        require(
            auctions[_index].pot < _calcPotFee(_amount),
            "This pot is low then already pot"
        ); // Ensure the new pot is greater than the current pot
        require(auctions[_index].owner != _player, "Owner can't pot"); // Owner cannot bid on their own auction

        require(
            auctions[_index].startPrice < _calcPotFee(_amount),
            "This pot is low then start Price"
        );

        if (auctions[_index].pot > auctions[_index].pot) {
            require(
                _amount <= ((auctions[_index].pot * MAX_POT_MULTIPLIER) / 100),
                "Pot exceeds maximum allowed increment"
            ); // Ensure the bid does not exceed the maximum allowed increment
        }

        coolDownControl(_player, _index); // Apply cooldown restrictions

        _depositErc20(_player, address(this), _amount); // Deposit bid amount
        uint amountLessFee = _paidPotFee(_amount); // Calculate amount after fees

        balanceUser[_player] += amountLessFee;
        // Lock the current player's funds
        _updateLockBalance(_player, amountLessFee, true);

        // Unlock the previous player's funds
        _updateLockBalance(
            auctions[_index].player,
            auctions[_index].pot,
            false
        );

        // Update auction state
        auctions[_index].player = _player; // Set the new player
        auctions[_index].pot = amountLessFee; // Update the pot value
    }

    /**
     * @dev Calculates the pot fee based on the input amount.
     *      Applies a fixed fee if the amount is below the price threshold, or a dynamic fee otherwise.
     * @param _amount The input amount to calculate the fee for.
     * @return uint The amount after deducting the calculated fee.
     */
    function _calcPotFee(uint _amount) internal view virtual returns (uint) {
        if (_amount < feeSystem.priceThreshold) {
            return _amount - feeSystem.fixedFee; // Apply fixed fee
        } else {
            return
                _amount - calculateBasisPoints(_amount, feeSystem.dinamicFee); // Apply dynamic fee
        }
    }

    /**
     * @dev Processes and deducts the pot fee from the input amount.
     *      The fee is added to the contract balance, and the remaining amount is returned.
     * @param _amount The input amount to deduct the fee from.
     * @return uint The amount after deducting the fee.
     * @notice Emits the `PaidFee` event with the input amount.
     */
    function _paidPotFee(uint _amount) internal virtual returns (uint) {
        if (_amount < feeSystem.priceThreshold) {
            contractBalance += feeSystem.fixedFee; // Add fixed fee to contract balance
            emit PaidFee(_amount); // Emit fee event
            return _amount - feeSystem.fixedFee; // Return amount after fee deduction
        } else {
            uint dynamicFee = calculateBasisPoints(
                _amount,
                feeSystem.dinamicFee
            ); // Calculate dynamic fee
            contractBalance += dynamicFee; // Add dynamic fee to contract balance
            emit PaidFee(_amount); // Emit fee event
            return _amount - dynamicFee; // Return amount after fee deduction
        }
    }

    /**
     * @dev Calculates the basis points (bps) fee for a given amount.
     * @param amount The input amount to calculate the fee for.
     * @param bps The basis points percentage to apply.
     * @return uint The calculated fee in the same unit as the input amount.
     * @notice 10000 basis points equal 100% (full amount).
     */
    function calculateBasisPoints(
        uint256 amount,
        uint256 bps
    ) internal pure virtual returns (uint) {
        return (amount * bps) / 10000; // Calculate the fee as (amount * bps) / 10000
    }

    /**
     * @dev Transfers ERC20 tokens from one address to another securely.
     *      Uses the `SafeERC20.safeTransferFrom` method to ensure a secure transfer.
     * @param _from Address of the sender of the tokens.
     * @param _to Address of the recipient of the tokens.
     * @param _amount The number of tokens to transfer.
     * @notice Assumes the ERC20 token is specified by the `money` address.
     */
    function _depositErc20(
        address _from,
        address _to,
        uint _amount
    ) internal virtual {
        SafeERC20.safeTransferFrom(IERC20(money), _from, _to, _amount); // Securely transfer tokens
    }

    /**
     * @dev Closes an auction after its expiration.
     *      Transfers the pot amount (minus fees) to the auction owner and updates the auction state.
     * @param _owner Address of the caller attempting to close the auction.
     * @param _index Index of the auction in the `auctions` array.
     * @notice Can be called by the auction owner, the highest bidder (player), or the contract owner.
     * @notice Emits the `PaidFee` event for the fee deduction.
     */
    function _closeAuction(address _owner, uint _index) internal virtual {
        require(
            auctions[_index].expired < block.timestamp,
            "This auction is not expired"
        ); // Ensure the auction has expired
        require(
            _owner == auctions[_index].owner ||
                _owner == auctions[_index].player ||
                _owner == owner(), // Allow only the owner, player, or contract owner
            "Not Owner"
        );
        require(auctions[_index].open == true, "This auction already close"); // Ensure the auction is still open
        auctions[_index].open = false; // Mark the auction as closed

        address newOwner = auctions[_index].player; // New owner is the highest bidder
        address oldOwner = auctions[_index].owner; // Old owner of the auction
        uint originalPot = auctions[_index].pot; // Deduct fees from the pot
        uint pot = _paidSellFee(auctions[_index].pot); // Deduct fees from the pot

        auctions[_index].pot = 0; // Reset the pot
        auctions[_index].owner = newOwner; // Update the owner to the highest bidder

        balanceUser[newOwner] -= originalPot; // Deduct the pot amount from the new owner's balance

        //lockBalance[newOwner] -= pot;
        _updateLockBalance(newOwner, originalPot, false); // Update the lock balance
        balanceUser[oldOwner] += pot; // Add the pot amount to the old owner's balance
    }

    /**
     * @dev Calculates and deducts the sell fee based on the pot amount.
     *      The fee is added to the contract balance, and the remaining amount is returned.
     * @param _amount The pot amount from which the sell fee is deducted.
     * @return uint The amount after deducting the sell fee.
     * @notice Emits the `PaidFee` event with the deducted fee amount.
     */
    function _paidSellFee(uint _amount) internal virtual returns (uint) {
        for (uint i; i < feeSeller.echelons.length; i++) {
            if (_amount < feeSeller.echelons[i]) {
                // Check if the amount falls in the current echelon
                uint fee = calculateBasisPoints(_amount, feeSeller.fees[i]); // Calculate the fee
                contractBalance += fee; // Add the fee to the contract balance
                emit PaidFee(fee); // Emit the fee event
                return _amount - fee; // Return the amount after fee deduction
            }
        }
        uint _fee = calculateBasisPoints(
            _amount,
            feeSeller.fees[feeSeller.fees.length - 1] // Use the last echelon fee if amount exceeds all echelons
        );
        contractBalance += _fee; // Add the fee to the contract balance
        emit PaidFee(_fee); // Emit the fee event
        return _amount - _fee; // Return the amount after fee deduction
    }

    /**
     * @dev Allows the auction owner to withdraw bonds from a closed auction.
     *      Ensures that the auction is closed and the contract holds sufficient bond balance.
     * @param _owner Address of the auction owner requesting the withdrawal.
     * @param _index Index of the auction in the `auctions` array.
     * @notice Emits the `WithDrawBond` event after successful withdrawal.
     */
    function _withDrawBond(address _owner, uint _index) internal virtual {
        require(_owner == auctions[_index].owner, "Not Owner"); // Ensure the caller is the auction owner
        require(
            auctions[_index].expired < block.timestamp,
            "This auction is not expired"
        ); // Ensure the auction has expired
        require(auctions[_index].open == false, "This auction is Open"); // Ensure the auction is closed

        uint contractBondBalance = IERC1155(bondContract).balanceOf(
            address(this),
            auctions[_index].id
        ); // Check the contract's bond balance
        require(
            contractBondBalance >= auctions[_index].amount,
            "Insufficient bond balance in contract"
        ); // Ensure sufficient bond balance in the contract

        uint amountBond = auctions[_index].amount; // Get the bond amount to be withdrawn
        auctions[_index].amount = 0; // Reset the bond amount in the auction
        _depositBond(
            address(this),
            auctions[_index].owner,
            auctions[_index].id,
            amountBond
        ); // Transfer the bonds back to the owner
        emit WithDrawBond(
            auctions[_index].owner,
            auctions[_index].id,
            amountBond
        ); // Emit the withdrawal event
    }

    /**
     * @dev Allows a user to withdraw funds (ERC20 tokens) from their balance.
     *      Ensures that the user has sufficient free balance to withdraw.
     * @param _user Address of the user requesting the withdrawal.
     * @param _amount Amount of funds to withdraw.
     * @notice The free balance is calculated as `balanceUser - lockBalance`.
     */
    function _withdrawMoney(address _user, uint _amount) internal virtual {
        require(
            _amount <= balanceUser[_user] - lockBalance[_user],
            "Insufficient free balance"
        ); // Ensure the user has sufficient free balance
        require(
            lockBalance[_user] <= balanceUser[_user] - _amount,
            "Incorrect Operation"
        ); // Ensure the operation does not leave an inconsistent state
        balanceUser[_user] -= _amount; // Deduct the amount from the user's balance
        SafeERC20.safeTransfer(IERC20(money), _user, _amount); // Transfer the funds to the user
    }

    /**
     * @dev Implements a cooldown mechanism to prevent rapid successive actions.
     *      Checks if the user can perform the action based on the last pot time.
     * @param _user Address of the user attempting the action.
     * @param _id ID of the auction for which the action is attempted.
     * @notice The cooldown duration is defined by the `coolDown` variable.
     */
    function coolDownControl(address _user, uint _id) internal virtual {
        require(
            lastPotTime[_user][_id] + coolDown < block.timestamp,
            "Wait for pot again"
        ); // Ensure the cooldown period has passed
        lastPotTime[_user][_id] = block.timestamp; // Update the last pot time for the user and auction
    }

    /**
     * @dev Handles the receipt of a single ERC1155 token type.
     *      This function is called whenever an ERC1155 token is transferred to this contract via `safeTransferFrom`.
     * @param operator Address which initiated the transfer (e.g., msg.sender).
     * @param from Address which previously owned the token.
     * @param id ID of the token being transferred.
     * @param value Amount of tokens being transferred.
     * @param data Additional data with no specified format.
     * @return bytes4 The function selector for `onERC1155Received` to confirm the token transfer.
     * @notice Currently, this function does not implement any custom logic. It simply confirms the receipt of the token.
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure returns (bytes4) {
        // Custom logic can be added here if needed
        return this.onERC1155Received.selector;
    }

    /**
     * @dev Handles the receipt of multiple ERC1155 token types in a batch.
     *      This function is called whenever multiple ERC1155 tokens are transferred to this contract via `safeBatchTransferFrom`.
     * @param operator Address which initiated the batch transfer (e.g., msg.sender).
     * @param from Address which previously owned the tokens.
     * @param ids Array of IDs of each token being transferred (order and length must match `values` array).
     * @param values Array of amounts of each token being transferred (order and length must match `ids` array).
     * @param data Additional data with no specified format.
     * @return bytes4 The function selector for `onERC1155BatchReceived` to confirm the batch token transfer.
     * @notice Currently, this function does not implement any custom logic. It simply confirms the receipt of the tokens.
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure returns (bytes4) {
        // Custom logic can be added here if needed
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev Returns the complete list of auctions.
     * @return An array containing all the auctions in the contract.
     */
    function showAuctionsList() public view virtual returns (Auction[] memory) {
        return auctions;
    }

    /**
     * @dev Returns the details of a specific auction.
     *      Ensures the index is within bounds using the `outIndex` modifier.
     * @param _index The index of the auction to retrieve.
     * @return An `Auction` struct containing details of the specified auction.
     */
    function showAuction(
        uint _index
    ) public view virtual outIndex(_index) returns (Auction memory) {
        return auctions[_index];
    }

    /**
     * @dev Returns the current fee system configuration.
     * @return A `FeeSystem` struct containing the fixed fee, price threshold, and dynamic fee.
     */
    function showFeesSystem() public view virtual returns (FeeSystem memory) {
        return feeSystem;
    }

    /**
     * @dev Returns the current fee configuration for sellers.
     * @return A `FeeSeller` struct containing the echelons and corresponding fees.
     */
    function showFeesSeller() public view virtual returns (FeeSeller memory) {
        return feeSeller;
    }

    /**
     * @dev Returns the total accumulated fees in the contract.
     *      Primarily used for testing purposes.
     * @return The total amount of fees stored in the contract.
     */
    function showBalanceFee() public view virtual returns (uint) {
        return contractBalance;
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
     * @dev Returns the address of the bond contract.
     * @return The address of the bond contract currently set in the system.
     * @notice This function provides visibility into the bond contract address
     *         for external users or systems interacting with the contract.
     */
    function showBondContractAddress() public view returns (address) {
        return bondContract;
    }
}
