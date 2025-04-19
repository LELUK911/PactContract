// SPDX-License-Identifier: Leluk911

pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// Import the interface for ERC20 tokens, enabling interaction with token contracts for operations
// like transfers, balance checks, and approvals.

import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
// Import the interface for ERC1155 tokens, allowing interaction with contracts that follow the
// ERC1155 multi-token standard, including transfers and balance queries.

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// Import the SafeERC20 library, which wraps ERC20 operations to ensure safety by handling
// potential issues like failed transfers and reentrancy attacks.

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
// Import the IERC1155Receiver interface, which specifies the required functions for contracts
// that want to receive and manage ERC1155 tokens securely.

import {PactLaunchStorage} from "./PactLaunchStorage.sol";
// Import the PactLaunchStorage contract, which defines the storage structure and essential
// variables for managing the pact launch system in the application.

import "./interface/Ibond.sol";
// Import the IPact interface, defining the standard methods for interacting with the pact
// contract, ensuring seamless integration with pact-specific logic.

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
// Import the Pausable contract, which provides the functionality to temporarily halt contract
// operations for maintenance or emergency purposes.

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// Import the ReentrancyGuard contract to prevent reentrancy attacks by ensuring that functions
// cannot be called again while already executing.

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// Import the Ownable contract to enable ownership management, allowing privileged operations
// to be restricted to the contract owner.

//import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
//import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
//import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
//import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {console} from "hardhat/console.sol";

contract PactLaunch is
    PactLaunchStorage, // Inherits the storage structure and variables for the PactLaunch system.
    Pausable, // Allows the contract to be paused and unpaused by the owner.
    ReentrancyGuard, // Prevents reentrancy attacks in critical functions.
    Ownable // Provides ownership control functionality for the contract.
{
    /**
     * @dev Emitted when a new pact is launched for sale.
     * @param _user Address of the user who created the pact.
     * @param _id ID of the pact being launched.
     * @param _amount Number of pact units being launched for sale.
     */
    event NewPactInLaunch(
        address indexed _user,
        uint indexed _id,
        uint _amount
    );

    /**
     * @dev Emitted when additional units of an existing pact are added to the sale.
     * @param _user Address of the user who is adding more pact units.
     * @param _id ID of the pact being incremented.
     * @param _amount Number of additional pact units added for sale.
     */
    event IncrementPactInLaunch(
        address indexed _user,
        uint indexed _id,
        uint _amount
    );

    /**
     * @dev Emitted when a pact is purchased.
     * @param buyer Address of the user buying the pact.
     * @param amount Number of pact units purchased.
     */
    event BuyPact(address indexed buyer, uint indexed amount,uint indexed id);

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
     * @dev Event emitted when a pact is removed from sale.
     * @param _user Address of the user who removed the pact.
     * @param _id ID of the pact removed from sale.
     */
    event DeleteLaunch(address indexed _user, uint indexed _id);

    constructor(address _pactContract) Ownable(msg.sender) {
        pactContract = _pactContract;
    }

    /*
    /**
     * @dev Proxy initializer function to replace the constructor.
     *      This function is used for initializing the contract when deployed as an upgradeable proxy.
     * @param _owner Address of the owner to set for the contract.
    
    function initialize(address _owner) public initializer {
        __Ownable_init(); // Initializes the OwnableUpgradeable contract to handle ownership.
        transferOwnership(_owner); // Transfers ownership to the specified owner address.
    }*/

    /**
     * @dev Sets the address of the pact contract.
     *      This function can only be called by the owner of the contract.
     * @param _pactContract Address of the pact contract to be set.
     * @notice The address provided must not be the zero address.
     */
    function setPactContractAddress(address _pactContract) external onlyOwner {
        require(_pactContract != address(0), "set correct Address"); // Validates the pact contract address.
        pactContract = _pactContract; // Updates the pact contract address.
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
     * @dev Allows a user to launch a new pact for sale.
     *      Pacts can only be launched when the contract is not paused.
     *      Uses nonReentrant to prevent reentrancy attacks.
     * @param _id The ID of the pact to be launched.
     * @param _amount The number of pact units to be launched for sale.
     */
    function launchNewPact(
        uint _id,
        uint _amount
    ) external nonReentrant whenNotPaused {
        _launchNewPact(msg.sender, _id, _amount); // Internal function to handle the pact launch.
    }

    /**
     * @dev Allows a user to buy a pact currently on sale.
     *      Pacts can only be purchased when the contract is not paused.
     *      Uses nonReentrant to prevent reentrancy attacks.
     * @param _id The ID of the pact being purchased.
     * @param _index The index of the pact in the pact list.
     * @param _amount The number of pact units to purchase.
     */
    function buyPact(
        uint _id,
        uint _index,
        uint _amount
    ) external nonReentrant whenNotPaused {
        _buyPact(msg.sender, _id, _index, _amount); // Internal function to handle pact purchase.
    }

    /**
     * @dev Allows a user to withdraw pacts they have purchased.
     *      Pacts can only be withdrawn when the contract is not paused.
     *      Uses nonReentrant to prevent reentrancy attacks.
     * @param _id The ID of the pact being withdrawn.
     */
    function withdrawPactBuy(uint _id) external nonReentrant whenNotPaused {
        require(pactBuyForUser[msg.sender][_id]>0,"Not pact for withdraw");
        uint amount = pactBuyForUser[msg.sender][_id]; // Retrieve the number of pacts purchased by the user.
        pactBuyForUser[msg.sender][_id] = 0; // Reset the user's purchased pact balance.
        _depositPact(address(this), msg.sender, _id, amount); // Transfer the pacts to the user.
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
     * @dev Allows a user to delete a pact they have launched for sale.
     *      Pacts can only be deleted when the contract is not paused.
     *      Uses nonReentrant to prevent reentrancy attacks.
     * @param _id The ID of the pact being deleted.
     * @param index The index of the pact in the pact list.
     */
    function deleteLaunch(
        uint _id,
        uint index
    ) external nonReentrant whenNotPaused {
        _deleteLaunch(msg.sender, _id, index); // Internal function to handle pact deletion.
    }

    /**
     * @dev Internal function to launch a new pact for sale.
     *      Validates the pact details and transfers the pact to the contract.
     * @param _user Address of the user launching the pact.
     * @param _id ID of the pact being launched.
     * @param _amount Number of pact units being launched for sale.
     */
    function _launchNewPact(address _user, uint _id, uint _amount) internal {
        PactDetails memory pactDetail = showPactDetail(_id); // Fetch pact details.

        require(
            pactDetail.debtor == _user,
            "Only debtor Pact can launch this function"
        ); // Ensure only the pact debtor can launch it.
        require(_amount > 0, "Set correct amount"); // Validate that the amount is greater than 0.
        require(_amount <= pactDetail.amount, "Set correct amount"); // Validate that the amount does not exceed the pact's total supply.

        _depositPact(_user, address(this), _id, _amount); // Transfer the pact from the user to the contract.
        amountInSell[_id] = IERC1155(pactContract).balanceOf(
            address(this),
            _id
        ); // Update the amount of pacts available for sale.

        (, bool response) = _srcIndexListPacts(_id); // Check if the pact is already listed.
        if (!response) {
            listPacts.push(_id); // Add the pact to the list of pacts for sale.
            pactIndex[_id] = listPacts.length - 1; // Save the pact's index for quick access.
            emit IncrementPactInLaunch(_user, _id, _amount); // Emit an event for the pact launch.
        }
    }

    /**
     * @dev Internal function to transfer pacts from a user to the contract.
     *      Uses the ERC1155 `safeTransferFrom` function.
     * @param _user Address of the user sending the pacts.
     * @param _to Address of the recipient (contract).
     * @param _id ID of the pact being transferred.
     * @param _amount Number of pact units being transferred.
     */
    function _depositPact(
        address _user,
        address _to,
        uint _id,
        uint _amount
    ) internal {
        IERC1155(pactContract).safeTransferFrom(_user, _to, _id, _amount, ""); // Transfer the pact using ERC1155.
    }

    /**
     * @dev Internal function to handle the purchase of a pact.
     *      Validates the pact's availability and processes the payment.
     * @param _user Address of the user purchasing the pact.
     * @param _id ID of the pact being purchased.
     * @param _index Index of the pact in the list of pacts for sale.
     * @param _amount Number of pact units being purchased.
     */
    function _buyPact(
        address _user,
        uint _id,
        uint _index,
        uint _amount
    ) internal {
        require(listPacts[_index] == _id, "Pact not in sale"); // Ensure the pact is listed for sale.

        PactDetails memory pactDetail = showPactDetail(_id); // Fetch pact details.

        require(amountInSell[_id] > 0, "Pact is out of sale"); // Ensure there are pacts available for sale.
        require(_amount <= amountInSell[_id], "Digit correct amount for buy"); // Validate the amount being purchased.

        _moveErc20(
            pactDetail.tokenLoan,
            _user,
            address(this),
            _amount * pactDetail.sizeLoan
        ); // Transfer the payment from the buyer to the contract.

        amountInSell[_id] -= _amount; // Update the amount of pacts available for sale.
        balanceForToken[pactDetail.debtor][pactDetail.tokenLoan] +=
            _amount *
            pactDetail.sizeLoan; // Update the debtor's token balance.
        pactBuyForUser[_user][_id] += _amount; // Update the buyer's pact balance.
        emit BuyPact(_user, _amount,_id); // Emit an event for the pact purchase.
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
     * @dev Internal function to remove a pact from the sale list.
     *      Validates the pact details, updates the sale list, and returns the pact to the debtor.
     * @param _user Address of the pact debtor requesting the removal.
     * @param _id ID of the pact being removed from sale.
     * @param index Index of the pact in the `listPacts` array.
     * @notice The function ensures that the pact ID matches the provided index and that the pact is currently on sale.
     */
    function _deleteLaunch(address _user, uint _id, uint index) internal {
        require(listPacts[index] == _id, "Invalid index for pact ID"); // Ensure the pact ID matches the provided index.

        PactDetails memory pactDetail = showPactDetail(_id); // Fetch pact details.
        require(
            pactDetail.debtor == _user,
            "Only debtor Pact can launch this function"
        ); // Ensure only the debtor can delete the pact.

        require(amountInSell[_id] > 0, "Pact is not currently in sale"); // Ensure the pact is currently on sale.

        uint amountRefound = amountInSell[_id]; // Fetch the amount of pacts still available for sale.
        amountInSell[_id] = 0; // Reset the amount of pacts available for sale.

        (, bool response) = _srcIndexListPacts(_id); // Check if the pact is in the list.
        if (response) {
            listPacts[index] = listPacts[listPacts.length - 1]; // Replace the pact to be removed with the last pact in the array.
            listPacts.pop(); // Remove the last pact from the array to maintain consistency.
            delete pactIndex[_id]; // Delete the pact's index from the mapping.

            _depositPact(address(this), _user, _id, amountRefound); // Return the pact to the debtor.
            emit DeleteLaunch(_user, _id); // Emit an event for the pact removal.
        } else {
            revert("Pact not in sell!"); // Revert if the pact is not found in the list.
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
    function balanceDebtor(
        address _user,
        address _token
    ) public view returns (uint amount) {
        amount = balanceForToken[_user][_token]; // Retrieve the user's balance for the specified token.
    }

    /**
     * @dev Returns the number of pact units currently available for sale for a specific pact ID.
     * @param _id ID of the pact being queried.
     * @return amount Number of pact units available for sale.
     */
    function showAmountInSellForPact(
        uint _id
    ) public view returns (uint amount) {
        amount = amountInSell[_id]; // Retrieve the amount of pacts available for sale.
    }

    /**
     * @dev Fetches the details of a specific pact by ID.
     *      Makes an external call to the pact contract to retrieve the pact details.
     * @param _id ID of the pact being queried.
     * @return pact A `PactDetails` struct containing all information about the pact.
     * @notice This function relies on an external call and may revert if the call fails.
     */
    function showPactDetail(uint _id) public returns (PactDetails memory pact) {
        (bool success, bytes memory data) = pactContract.call(
            abi.encodeWithSignature("showDeatailPactForId(uint256)", _id)
        ); // External call to the pact contract to fetch details.
        require(success, "External call failed"); // Ensure the call was successful.

        (pact) = abi.decode(data, (PactDetails)); // Decode the returned data into a `PactDetails` struct.
    }

    /**
     * @dev Returns the list of all pact IDs currently available for sale.
     * @return _listPacts An array of pact IDs available for sale.
     */
    function showPactLaunchList()
        public
        view
        returns (uint[] memory _listPacts)
    {
        _listPacts = listPacts; // Return the array of pact IDs.
    }

    /**
     * @dev Internal function to find the index of a pact in the `listPacts` array.
     * @param _id ID of the pact being searched.
     * @return uint Index of the pact in the array if found.
     * @return bool True if the pact is found, false otherwise.
     */
    function _srcIndexListPacts(uint _id) internal view returns (uint, bool) {
        if (
            pactIndex[_id] < listPacts.length &&
            listPacts[pactIndex[_id]] == _id
        ) {
            return (pactIndex[_id], true); // Return the index and true if the pact exists.
        }
        return (type(uint).max, false); // Return max value and false if the pact does not exist.
    }

    /**
     * @dev Public function to retrieve the index of a pact in the `listPacts` array.
     *      Uses the internal `_srcIndexListPacts` function for the actual search.
     * @param _id ID of the pact being searched.
     * @return uint Index of the pact in the array.
     */
    function findIndexPact(uint _id) public view returns (uint) {
        (uint index, ) = _srcIndexListPacts(_id); // Call the internal function to find the index.
        return index; // Return the index.
    }

    /**
     * @dev Returns the number of pact units available for withdrawal for a given user and pact ID.
     * @param _user Address of the user whose withdrawal balance is being queried.
     * @param _id ID of the pact being queried.
     * @return amount Number of pact units available for withdrawal.
     */
    function showPactForWithdraw(
        address _user,
        uint _id
    ) external view returns (uint amount) {
        amount = pactBuyForUser[_user][_id]; // Retrieve the user's pact withdrawal balance.
    }

    /**
     * @dev Returns the address of the pact contract.
     * @return The address of the pact contract currently set in the system.
     * @notice This function provides visibility into the pact contract address
     *         for external users or systems interacting with the contract.
     */
    function showPactContractAddress() public view returns (address) {
        return pactContract;
    }
}
