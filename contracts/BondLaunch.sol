// SPDX-License-Identifier: Leluk911

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// Import the interface for ERC20 tokens, used for interacting with token contracts (e.g., transfers, approvals).

import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
// Import the interface for ERC1155 tokens, used for interacting with multi-token contracts.

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Import the SafeERC20 library, which provides safe wrappers for ERC20 operations to handle potential failures.

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
// Import the Address utility library, which contains helper functions for address type operations.

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
// Import the IERC1155Receiver interface, which must be implemented by contracts receiving ERC1155 tokens.

import {BondLaunchStorage} from "./BondLaunchStorage.sol";
// Import the BondLaunchStorage contract, which contains the storage structure and variables for the BondLaunch system.

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
// Import the PausableUpgradeable contract, used to implement a pausability feature for the contract.

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// Import the ReentrancyGuardUpgradeable contract, used to prevent reentrancy attacks.

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// Import the Initializable contract, used for initializing upgradeable contracts without constructors.

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// Import the OwnableUpgradeable contract, used to manage ownership and permissions in the upgradeable contract.

import "./interface/Ibond.sol";
// Import the IBond interface, which defines the functions required for interacting with the bond contract.

import {console} from "hardhat/console.sol";
//import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
//import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
//import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BondLaunch is
    BondLaunchStorage, // Inherits the storage structure and variables for the BondLaunch system.
    Initializable, // Enables the contract to be upgradeable by replacing constructors with initialization functions.
    PausableUpgradeable, // Allows the contract to be paused and unpaused by the owner.
    ReentrancyGuardUpgradeable, // Prevents reentrancy attacks in critical functions.
    OwnableUpgradeable // Provides ownership control functionality for the contract.
{
    /**
     * @dev Emitted when a new bond is launched for sale.
     * @param _user Address of the user who created the bond.
     * @param _id ID of the bond being launched.
     * @param _amount Number of bond units being launched for sale.
     */
    event NewBondInLaunch(
        address indexed _user,
        uint indexed _id,
        uint _amount
    );

    /**
     * @dev Emitted when additional units of an existing bond are added to the sale.
     * @param _user Address of the user who is adding more bond units.
     * @param _id ID of the bond being incremented.
     * @param _amount Number of additional bond units added for sale.
     */
    event IncrementBondInLaunch(
        address indexed _user,
        uint indexed _id,
        uint _amount
    );

    /**
     * @dev Emitted when a bond is purchased.
     * @param buyer Address of the user buying the bond.
     * @param amount Number of bond units purchased.
     */
    event BuyBond(address indexed buyer, uint indexed amount);

    /**
     * @dev Emitted when a user withdraws tokens from the contract.
     * @param user Address of the user withdrawing tokens.
     * @param token Address of the token being withdrawn.
     * @param amount Amount of the token being withdrawn.
     */
    event WithdrawToken(
        address indexed user,
        address indexed token,
        uint amount
    );

    /**
     * @dev Event emitted when a bond is removed from sale.
     * @param _user Address of the user who removed the bond.
     * @param _id ID of the bond removed from sale.
     */
    event DeleteLaunch(address indexed _user, uint indexed _id);

    /*
    constructor(address _bondContract) Ownable(msg.sender) {
        bondContract = _bondContract;
    }
*/

    //?PROXY CONSTRUCTOR
    /**
     * @dev Proxy initializer function to replace the constructor.
     *      This function is used for initializing the contract when deployed as an upgradeable proxy.
     * @param _owner Address of the owner to set for the contract.
     */
    function initialize(address _owner) public initializer {
        __Ownable_init(); // Initializes the OwnableUpgradeable contract to handle ownership.
        transferOwnership(_owner); // Transfers ownership to the specified owner address.
    }

    /**
     * @dev Sets the address of the bond contract.
     *      This function can only be called by the owner of the contract.
     * @param _bondContract Address of the bond contract to be set.
     * @notice The address provided must not be the zero address.
     */
    function setBondContractAddress(address _bondContract) external onlyOwner {
        require(_bondContract != address(0), "set correct Address"); // Validates the bond contract address.
        bondContract = _bondContract; // Updates the bond contract address.
    }

    /**
     * @dev Allows the contract owner to pause the contract.
     *      Pausing the contract restricts certain functions or transfers.
     *      This is useful in case of an emergency or to prevent unauthorized operations.
     *      Utilizes OpenZeppelin's Pausable functionality.
     */
    function setInPause() external onlyOwner {
        _pause(); // Pauses the contract, restricting operations annotated with `whenNotPaused`.
    }

    /**
     * @dev Allows the contract owner to unpause the contract.
     *      Restores normal operations after a pause.
     *      Utilizes OpenZeppelin's Pausable functionality.
     */
    function setUnPause() external onlyOwner {
        _unpause(); // Unpauses the contract, allowing operations previously restricted.
    }

    /**
     * @dev Allows a user to launch a new bond for sale.
     *      Bonds can only be launched when the contract is not paused.
     *      Uses nonReentrant to prevent reentrancy attacks.
     * @param _id The ID of the bond to be launched.
     * @param _amount The number of bond units to be launched for sale.
     */
    function launchNewBond(
        uint _id,
        uint _amount
    ) external nonReentrant whenNotPaused {
        _launchNewBond(msg.sender, _id, _amount); // Internal function to handle the bond launch.
    }

    /**
     * @dev Allows a user to buy a bond currently on sale.
     *      Bonds can only be purchased when the contract is not paused.
     *      Uses nonReentrant to prevent reentrancy attacks.
     * @param _id The ID of the bond being purchased.
     * @param _index The index of the bond in the bond list.
     * @param _amount The number of bond units to purchase.
     */
    function buyBond(
        uint _id,
        uint _index,
        uint _amount
    ) external nonReentrant whenNotPaused {
        _buyBond(msg.sender, _id, _index, _amount); // Internal function to handle bond purchase.
    }

    /**
     * @dev Allows a user to withdraw bonds they have purchased.
     *      Bonds can only be withdrawn when the contract is not paused.
     *      Uses nonReentrant to prevent reentrancy attacks.
     * @param _id The ID of the bond being withdrawn.
     */
    function withdrawBondBuy(uint _id) external nonReentrant whenNotPaused {
        uint amount = bondBuyForUser[msg.sender][_id]; // Retrieve the number of bonds purchased by the user.
        bondBuyForUser[msg.sender][_id] = 0; // Reset the user's purchased bond balance.
        _depositBond(address(this), msg.sender, _id, amount); // Transfer the bonds to the user.
    }

    /**
     * @dev Allows a user to withdraw tokens from their balance in the contract.
     *      Tokens can only be withdrawn when the contract is not paused.
     *      Uses nonReentrant to prevent reentrancy attacks.
     * @param _token The address of the token being withdrawn.
     */
    function withdrawToken(address _token) external nonReentrant whenNotPaused {
        _withdrawToken(_token, msg.sender); // Internal function to handle token withdrawal.
    }

    /**
     * @dev Allows a user to delete a bond they have launched for sale.
     *      Bonds can only be deleted when the contract is not paused.
     *      Uses nonReentrant to prevent reentrancy attacks.
     * @param _id The ID of the bond being deleted.
     * @param index The index of the bond in the bond list.
     */
    function deleteLaunch(
        uint _id,
        uint index
    ) external nonReentrant whenNotPaused {
        _deleteLaunch(msg.sender, _id, index); // Internal function to handle bond deletion.
    }

    /**
     * @dev Internal function to launch a new bond for sale.
     *      Validates the bond details and transfers the bond to the contract.
     * @param _user Address of the user launching the bond.
     * @param _id ID of the bond being launched.
     * @param _amount Number of bond units being launched for sale.
     */
    function _launchNewBond(address _user, uint _id, uint _amount) internal {
        BondDetails memory bondDetail = showBondDetail(_id); // Fetch bond details.

        require(
            bondDetail.issuer == _user,
            "Only issuer Bond can launch this function"
        ); // Ensure only the bond issuer can launch it.
        require(_amount > 0, "Set correct amount"); // Validate that the amount is greater than 0.
        require(_amount <= bondDetail.amount, "Set correct amount"); // Validate that the amount does not exceed the bond's total supply.

        _depositBond(_user, address(this), _id, _amount); // Transfer the bond from the user to the contract.
        amountInSell[_id] = IERC1155(bondContract).balanceOf(
            address(this),
            _id
        ); // Update the amount of bonds available for sale.

        (, bool response) = _srcIndexListBonds(_id); // Check if the bond is already listed.
        if (!response) {
            listBonds.push(_id); // Add the bond to the list of bonds for sale.
            bondIndex[_id] = listBonds.length - 1; // Save the bond's index for quick access.
            emit IncrementBondInLaunch(_user, _id, _amount); // Emit an event for the bond launch.
        }
    }

    /**
     * @dev Internal function to transfer bonds from a user to the contract.
     *      Uses the ERC1155 `safeTransferFrom` function.
     * @param _user Address of the user sending the bonds.
     * @param _to Address of the recipient (contract).
     * @param _id ID of the bond being transferred.
     * @param _amount Number of bond units being transferred.
     */
    function _depositBond(
        address _user,
        address _to,
        uint _id,
        uint _amount
    ) internal {
        IERC1155(bondContract).safeTransferFrom(_user, _to, _id, _amount, ""); // Transfer the bond using ERC1155.
    }

    /**
     * @dev Internal function to handle the purchase of a bond.
     *      Validates the bond's availability and processes the payment.
     * @param _user Address of the user purchasing the bond.
     * @param _id ID of the bond being purchased.
     * @param _index Index of the bond in the list of bonds for sale.
     * @param _amount Number of bond units being purchased.
     */
    function _buyBond(
        address _user,
        uint _id,
        uint _index,
        uint _amount
    ) internal {
        require(listBonds[_index] == _id, "Bond not in sale"); // Ensure the bond is listed for sale.

        BondDetails memory bondDetail = showBondDetail(_id); // Fetch bond details.

        require(amountInSell[_id] > 0, "Bond is out of sale"); // Ensure there are bonds available for sale.
        require(_amount <= amountInSell[_id], "Digit correct amount for buy"); // Validate the amount being purchased.

        _moveErc20(
            bondDetail.tokenLoan,
            _user,
            address(this),
            _amount * bondDetail.sizeLoan
        ); // Transfer the payment from the buyer to the contract.

        amountInSell[_id] -= _amount; // Update the amount of bonds available for sale.
        balanceForToken[bondDetail.issuer][bondDetail.tokenLoan] +=
            _amount *
            bondDetail.sizeLoan; // Update the issuer's token balance.
        bondBuyForUser[_user][_id] += _amount; // Update the buyer's bond balance.
        emit BuyBond(_user, _amount); // Emit an event for the bond purchase.
    }

    /**
     * @dev Internal function to withdraw tokens from the contract.
     *      Transfers the user's token balance to their address.
     * @param _token Address of the token being withdrawn.
     * @param _user Address of the user withdrawing the tokens.
     */
    function _withdrawToken(address _token, address _user) internal {
        uint amount = balanceForToken[msg.sender][_token]; // Fetch the user's token balance.
        balanceForToken[msg.sender][_token] = 0; // Reset the user's token balance.
        SafeERC20.safeTransfer(IERC20(_token), _user, amount); // Transfer the tokens to the user.
        emit WithdrawToken(_user, _token, amount); // Emit an event for the token withdrawal.
    }

    /**
     * @dev Internal function to safely transfer ERC20 tokens from one address to another.
     *      Utilizes OpenZeppelin's `SafeERC20` library to ensure secure token transfers.
     * @param _token Address of the ERC20 token being transferred.
     * @param _from Address of the sender.
     * @param _to Address of the recipient.
     * @param _amount Amount of tokens to be transferred.
     */
    function _moveErc20(
        address _token,
        address _from,
        address _to,
        uint _amount
    ) internal {
        SafeERC20.safeTransferFrom(IERC20(_token), _from, _to, _amount); // Secure token transfer.
    }

    /**
     * @dev Internal function to remove a bond from the sale list.
     *      Validates the bond details, updates the sale list, and returns the bond to the issuer.
     * @param _user Address of the bond issuer requesting the removal.
     * @param _id ID of the bond being removed from sale.
     * @param index Index of the bond in the `listBonds` array.
     * @notice The function ensures that the bond ID matches the provided index and that the bond is currently on sale.
     */
    function _deleteLaunch(address _user, uint _id, uint index) internal {
        require(listBonds[index] == _id, "Invalid index for bond ID"); // Ensure the bond ID matches the provided index.

        BondDetails memory bondDetail = showBondDetail(_id); // Fetch bond details.
        require(
            bondDetail.issuer == _user,
            "Only issuer Bond can launch this function"
        ); // Ensure only the issuer can delete the bond.

        require(amountInSell[_id] > 0, "Bond is not currently in sale"); // Ensure the bond is currently on sale.

        uint amountRefound = amountInSell[_id]; // Fetch the amount of bonds still available for sale.
        amountInSell[_id] = 0; // Reset the amount of bonds available for sale.

        (, bool response) = _srcIndexListBonds(_id); // Check if the bond is in the list.
        if (response) {
            listBonds[index] = listBonds[listBonds.length - 1]; // Replace the bond to be removed with the last bond in the array.
            listBonds.pop(); // Remove the last bond from the array to maintain consistency.
            delete bondIndex[_id]; // Delete the bond's index from the mapping.

            _depositBond(address(this), _user, _id, amountRefound); // Return the bond to the issuer.
            emit DeleteLaunch(_user, _id); // Emit an event for the bond removal.
        } else {
            revert("Bond not in sell!"); // Revert if the bond is not found in the list.
        }
    }

    /**
     * @dev ERC1155 Receiver callback function for single token transfers.
     *      This function is called whenever the contract receives an ERC1155 token.
     *      It ensures the contract complies with the ERC1155 standard.
     * @param operator Address which initiated the transfer (e.g., msg.sender).
     * @param from Address which previously owned the token.
     * @param id ID of the token being transferred.
     * @param value Amount of tokens being transferred.
     * @param data Additional data with no specified format.
     * @return bytes4 The function selector to confirm the token transfer.
     *         Returns `this.onERC1155Received.selector` as required by the ERC1155 standard.
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @dev ERC1155 Receiver callback function for batch token transfers.
     *      This function is called whenever the contract receives multiple ERC1155 tokens in a batch.
     *      It ensures the contract complies with the ERC1155 standard.
     * @param operator Address which initiated the batch transfer (e.g., msg.sender).
     * @param from Address which previously owned the tokens.
     * @param ids Array of IDs of tokens being transferred.
     * @param values Array of amounts of tokens being transferred for each ID.
     * @param data Additional data with no specified format.
     * @return bytes4 The function selector to confirm the batch token transfer.
     *         Returns `this.onERC1155BatchReceived.selector` as required by the ERC1155 standard.
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @dev Returns the balance of a specific token for a given user.
     * @param _user Address of the user whose balance is being queried.
     * @param _token Address of the token being queried.
     * @return amount The user's token balance in the contract.
     */
    function balanceIssuer(
        address _user,
        address _token
    ) public view returns (uint amount) {
        amount = balanceForToken[_user][_token]; // Retrieve the user's balance for the specified token.
    }

    /**
     * @dev Returns the number of bond units currently available for sale for a specific bond ID.
     * @param _id ID of the bond being queried.
     * @return amount Number of bond units available for sale.
     */
    function showAmountInSellForBond(
        uint _id
    ) public view returns (uint amount) {
        amount = amountInSell[_id]; // Retrieve the amount of bonds available for sale.
    }

    /**
     * @dev Fetches the details of a specific bond by ID.
     *      Makes an external call to the bond contract to retrieve the bond details.
     * @param _id ID of the bond being queried.
     * @return bond A `BondDetails` struct containing all information about the bond.
     * @notice This function relies on an external call and may revert if the call fails.
     */
    function showBondDetail(uint _id) public returns (BondDetails memory bond) {
        (bool success, bytes memory data) = bondContract.call(
            abi.encodeWithSignature("showDeatailBondForId(uint256)", _id)
        ); // External call to the bond contract to fetch details.
        require(success, "External call failed"); // Ensure the call was successful.

        (bond) = abi.decode(data, (BondDetails)); // Decode the returned data into a `BondDetails` struct.
    }

    /**
     * @dev Returns the list of all bond IDs currently available for sale.
     * @return _listBonds An array of bond IDs available for sale.
     */
    function showBondLaunchList()
        public
        view
        returns (uint[] memory _listBonds)
    {
        _listBonds = listBonds; // Return the array of bond IDs.
    }

    /**
     * @dev Internal function to find the index of a bond in the `listBonds` array.
     * @param _id ID of the bond being searched.
     * @return uint Index of the bond in the array if found.
     * @return bool True if the bond is found, false otherwise.
     */
    function _srcIndexListBonds(uint _id) internal view returns (uint, bool) {
        if (
            bondIndex[_id] < listBonds.length &&
            listBonds[bondIndex[_id]] == _id
        ) {
            return (bondIndex[_id], true); // Return the index and true if the bond exists.
        }
        return (type(uint).max, false); // Return max value and false if the bond does not exist.
    }

    /**
     * @dev Public function to retrieve the index of a bond in the `listBonds` array.
     *      Uses the internal `_srcIndexListBonds` function for the actual search.
     * @param _id ID of the bond being searched.
     * @return uint Index of the bond in the array.
     */
    function findIndexBond(uint _id) public view returns (uint) {
        (uint index, ) = _srcIndexListBonds(_id); // Call the internal function to find the index.
        return index; // Return the index.
    }

    /**
     * @dev Returns the number of bond units available for withdrawal for a given user and bond ID.
     * @param _user Address of the user whose withdrawal balance is being queried.
     * @param _id ID of the bond being queried.
     * @return amount Number of bond units available for withdrawal.
     */
    function showBondForWithdraw(
        address _user,
        uint _id
    ) external view returns (uint amount) {
        amount = bondBuyForUser[_user][_id]; // Retrieve the user's bond withdrawal balance.
    }
}
