// SPDX-License-Identifier: Leluk911

pragma solidity ^0.8.24;

/**
 * @title BondLaunchStorage
 * @dev This contract represents the storage structure for the BondLaunch contract.
 *      It contains all variables and structures needed to manage bonds and their information.
 */
contract BondLaunchStorage {
    // Address of the contract managing ERC1155 bonds.
    address internal bondContract;

    /**
     * @dev Data structure representing bond details.
     * @param id Unique ID of the bond.
     * @param issuer Address of the bond creator.
     * @param tokenLoan Address of the token used as a loan.
     * @param sizeLoan Loan size for each bond unit.
     * @param interest Interest rate percentage of the bond.
     * @param couponMaturity Array of maturity dates for coupons (in UNIX timestamp).
     * @param expiredBond UNIX timestamp of the bond's expiration.
     * @param tokenCollateral Address of the token used as collateral.
     * @param collateral Amount of collateral deposited.
     * @param balancLoanRepay Remaining balance to repay the loan.
     * @param describes Text description of the bond.
     * @param amount Total amount of bonds issued.
     */
    struct BondDetails {
        uint id;
        address issuer;
        address tokenLoan;
        uint sizeLoan;
        uint interest;
        uint[] couponMaturity;
        uint expiredBond;
        address tokenCollateral;
        uint collateral;
        uint balancLoanRepay;
        string describes;
        uint amount;
    }

    // Mapping that associates bond IDs with their respective indices in the `listBonds` array.
    mapping(uint => uint) internal bondIndex;

    // Mapping that tracks the balance for each user and specific token.
    // Useful for managing token payments or balances derived from bond purchases.
    mapping(address => mapping(address => uint)) internal balanceForToken;

    // Mapping that tracks the amount of bonds available for sale for each bond ID.
    // Acts as a secondary control on bond availability.
    mapping(uint => uint) internal amountInSell;

    // Array that maintains the list of all bonds currently available for sale.
    // Allows for quick iteration over available bond IDs.
    uint[] internal listBonds;

    // Mapping that tracks the number of bonds purchased by each user for each bond ID.
    // Useful for allowing users to withdraw purchased bonds.
    mapping(address => mapping(uint => uint)) internal bondBuyForUser;
}
