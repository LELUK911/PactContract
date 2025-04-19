// SPDX-License-Identifier: Leluk911

pragma solidity ^0.8.24;

/**
 * @title PactLaunchStorage
 * @dev This contract represents the storage structure for the PactLaunch contract.
 *      It contains all variables and structures needed to manage pacts and their information.
 */
contract PactLaunchStorage {
    // Address of the contract managing ERC1155 pacts.
    address internal pactContract;

    /**
     * @dev Data structure representing pact details.
     * @param id Unique ID of the pact.
     * @param debtor Address of the pact creator.
     * @param tokenLoan Address of the token used as a loan.
     * @param sizeLoan Loan size for each pact unit.
     * @param interest Reward rate percentage of the pact.
     * @param rewardMaturity Array of maturity dates for rewards (in UNIX timestamp).
     * @param expiredPact UNIX timestamp of the pact's expiration.
     * @param tokenCollateral Address of the token used as collateral.
     * @param collateral Amount of collateral deposited.
     * @param balancLoanRepay Remaining balance to repay the loan.
     * @param describes Text description of the pact.
     * @param amount Total amount of pacts issued.
     */
    struct PactDetails {
        uint id;
        address debtor;
        address tokenLoan;
        uint sizeLoan;
        uint interest;
        uint[] rewardMaturity;
        uint expiredPact;
        address tokenCollateral;
        uint collateral;
        uint balancLoanRepay;
        string describes;
        uint amount;
    }

    // Mapping that associates pact IDs with their respective indices in the `listPacts` array.
    mapping(uint => uint) internal pactIndex;

    // Mapping that tracks the balance for each user and specific token.
    // Useful for managing token payments or balances derived from pact purchases.
    mapping(address => mapping(address => uint)) internal balanceForToken;

    // Mapping that tracks the amount of pacts available for sale for each pact ID.
    // Acts as a secondary control on pact availability.
    mapping(uint => uint) internal amountInSell;

    // Array that maintains the list of all pacts currently available for sale.
    // Allows for quick iteration over available pact IDs.
    uint[] internal listPacts;

    // Mapping that tracks the number of pacts purchased by each user for each pact ID.
    // Useful for allowing users to withdraw purchased pacts.
    mapping(address => mapping(uint => uint)) internal pactBuyForUser;
}
