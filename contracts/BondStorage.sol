// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.24;


contract BondStorage {

/**
 * @dev This struct represents the core details of a bond:
 * - id: a unique identifier assigned to each bond by the contract.
 * - issuer: the address that creates (issues) the bond.
 * - tokenLoan: the ERC20 token used to represent the principal of the loan.
 * - sizeLoan: the total amount of the loan that the issuer is seeking.
 * - interest: the interest rate or amount to be paid on the bond.
 * - couponMaturity: an array of timestamps indicating when coupons (interest payments) mature.
 * - expiredBond: the timestamp after which the bond is fully matured.
 * - tokenCollateral: the address of the token set aside as collateral.
 * - collateral: the amount of collateral locked to secure the bond.
 * - balancLoanRepay: how many tokens are available to repay the loan at any given time.
 * - describes: a descriptive string providing extra bond details.
 * - amount: the total supply of the bond token to be minted.
 */
struct Bond {
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

/**
 * @dev This struct defines custom conditions related to fees and penalties:
 * - penalityForLiquidation: an array with up to 3 penalty tiers applied upon liquidation events.
 * - score: a rating or “trust score” for the issuer, influencing fee rates and penalties.
 */
struct ConditionOfFee {
    uint[3] penalityForLiquidation;
    uint score;
}

/**
 * @dev Core addresses and fee parameters:
 * - launcherContract: the official launch contract's address where the first transfer must go.
 * - transfertFee: the fixed fee (in WETH) for transfers, when both parties are outside the ecosystem.
 * - WHET: address of the WETH (or other ERC20) token used for fee payments.
 * - MAX_COUPONS: Defines the maximum number of coupons allowed per bond
 * - treasure: wallets abandon treasury functions
 *
 * @dev bondId:
 * - An incremental counter that uniquely identifies each bond.
 * - Not controlled by users or issuers, ensuring the integrity of bond IDs.
 */
address internal launcherContract;
uint internal transfertFee;
address internal WHET;
uint internal MAX_COUPONS;
address internal treasury;
uint internal bondId;
uint internal COUPON_FEE = 5;
uint[4] internal LIQUIDATION_FEE = [5,15,30,50];



// Case 1: new user or medium range
uint[3] internal mediumPenalties = [uint(100), uint(200), uint(400)];
// Case 2: high score (>1M)
uint[3] internal highPenalties = [uint(50), uint(100), uint(200)];
// Case 3: low score [500k, 700k)
uint[3] internal lowPenalties = [uint(200), uint(400), uint(600)];
// Case 4: very low score (<500k)
uint[3] internal veryLowPenalties = [uint(280), uint(450), uint(720)];


/**
 * @dev Maps each address to its ConditionOfFee struct, defining penalties and score.
 */
mapping(address => ConditionOfFee) internal conditionOfFee;

/**
 * @dev Maps a bond ID to the number of liquidation events that have occurred on that bond.
 */
mapping(uint => uint) internal numberOfLiquidations;

/**
 * @dev Tracks the total supply of each bond (ERC1155) identified by its token ID.
 */
mapping(uint256 => uint256) internal _totalSupply;

/**
 * @dev Maps a bond ID to its detailed Bond struct, storing all bond information.
 */
mapping(uint => Bond) internal bond;

/**
 * @dev couponToClaim[bondId][userAddress][couponIndex] stores how many coupons
 *      a given user can claim for a specific coupon index of a particular bond.
 */
mapping(uint => mapping(address => mapping(uint => uint))) couponToClaim;

/**
 * @dev Indicates if collateral is frozen for a given bond ID (e.g., when issuer is in default).
 *      0 means not frozen; any non-zero value represents a freeze state.
 */
mapping(uint => uint8) internal freezCollateral;

/**
 * @dev prizeScore[bondId][address] holds the number of “reward points” each address can earn for a bond.
 */
mapping(uint => mapping(address => uint)) internal prizeScore;

/**
 * @dev prizeScoreAlreadyClaim[bondId][address] indicates how many reward points have
 *      already been claimed by an address for a given bond.
 */
mapping(uint => mapping(address => uint)) internal prizeScoreAlreadyClaim;

/**
 * @dev claimedPercentage[bondId][address] tracks the percentage (out of 100) of
 *      reward points claimed by an address for a given bond.
 */
mapping(uint => mapping(address => uint)) internal claimedPercentage;

/**
 * @dev ecosistemAddress[address] marks whether an address belongs to the “ecosystem” 
 *      (exempt from certain fees or special rules).
 */
mapping(address => bool) internal ecosistemAddress;

/**
 * @dev firstTransfer[bondId] indicates whether the next transfer for a bond must go
 *      to the launcher contract (enforcing a “first transfer” rule).
 */
mapping(uint => bool) internal firstTransfer;

/**
 * @dev Tracks the contract’s collected fees for each ERC20 token.
 *      Key:   The token's address.
 *      Value: The total amount of that token held by the contract as fees.
 */
mapping(address => uint) internal balanceContractFeesForToken;


mapping(uint=>uint) internal liquidationFactor;













   





}




