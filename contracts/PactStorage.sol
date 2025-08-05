// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.24;

contract PactStorage {
    /**
     * @dev This struct represents the core details of a pact:
     * - id: a unique identifier assigned to each pact by the contract.
     * - debtor: the address that creates (issues) the pact.
     * - tokenLoan: the ERC20 token used to represent the principal of the loan.
     * - sizeLoan: the total amount of the loan that the debtor is seeking.
     * - interest: the interest rate or amount to be paid on the pact.
     * - rewardMaturity: an array of timestamps indicating when rewards (interest payments) mature.
     * - expiredPact: the timestamp after which the pact is fully matured.
     * - tokenCollateral: the address of the token set aside as collateral.
     * - collateral: the amount of collateral locked to secure the pact.
     * - balancLoanRepay: how many tokens are available to repay the loan at any given time.
     * - describes: a descriptive string providing extra pact details.
     * - amount: the total supply of the pact token to be minted.
     */
    struct Pact {
        uint id;
        address debtor;
        address tokenLoan;
        uint sizeLoan;
        uint interest;
        uint64[] rewardMaturity;
        uint64 expiredPact;
        address tokenCollateral;
        uint collateral;
        uint balancLoanRepay;
        string describes;
        uint amount;
    }

    /**
     * @dev This struct defines custom conditions related to fees and penalties:
     * - penalityForLiquidation: an array with up to 3 penalty tiers applied upon liquidation events.
     * - score: a rating or “trust score” for the debtor, influencing fee rates and penalties.
     */
    struct ConditionOfFee {
        uint16[3] penalityForLiquidation;
        uint score;
    }

    /**
     * @dev Core addresses and fee parameters:
     * - launcherContract: the official launch contract's address where the first transfer must go.
     * - transfertFee: the fixed fee (in WETH) for transfers, when both parties are outside the ecosystem.
     * - WHET: address of the WETH (or other ERC20) token used for fee payments.
     * - MAX_REWARDS: Defines the maximum number of rewards allowed per pact
     * - treasure: wallets abandon treasury functions
     *
     * @dev pactId:
     * - An incremental counter that uniquely identifies each pact.
     * - Not controlled by users or issuers, ensuring the integrity of pact IDs.
     */
    address internal launcherContract;
    uint internal transfertFee;
    address internal WHET;
    uint8 internal MAX_REWARDS;
    address internal treasury;
    uint internal pactId;
    uint16 internal REWARD_FEE = 5;
    uint16[4] internal LIQUIDATION_FEE = [5, 15, 30, 50];

    // Case 1: new user or medium range
    uint16[3] internal mediumPenalties = [
        100,
        200,
        400
    ];
    // C16ase 2: high score (>1M)
    uint16[3] internal highPenalties = [50, 100, 200];
    // C16ase 3: low score [500k, 700k)
    uint16[3] internal lowPenalties = [200, 400, 600];
    // C16ase 4: very low score (<500k)
    uint16[3] internal veryLowPenalties = [
        280,
        450,
        720
    ];

    /**
     * @dev Maps each address to its ConditionOfFee struct, defining penalties and score.
     */
    mapping(address => ConditionOfFee) internal conditionOfFee;

    /**
     * @dev Maps a pact ID to the number of liquidation events that have occurred on that pact.
     */
    mapping(uint => uint8) internal numberOfLiquidations;

    /**
     * @dev Tracks the total supply of each pact (ERC1155) identified by its token ID.
     */
    mapping(uint256 => uint256) internal _totalSupply;

    /**
     * @dev Maps a pact ID to its detailed Pact struct, storing all pact information.
     */
    mapping(uint => Pact) internal pact;

    /**
     * @dev rewardToClaim[pactId][userAddress][rewardIndex] stores how many rewards
     *      a given user can claim for a specific scheduled reward index of a particular pact.
     */
    mapping(uint => mapping(address => mapping(uint => uint))) rewardToClaim;

    /**
     * @dev Indicates if collateral is frozen for a given pact ID (e.g., when debtor is in default).
     *      0 means not frozen; any non-zero value represents a freeze state.
     */
    mapping(uint => uint8) internal freezCollateral;

    /**
     * @dev prizeScore[pactId][address] holds the number of “reward points” each address can earn for a pact.
     */
    mapping(uint => mapping(address => uint)) internal prizeScore;

    /**
     * @dev prizeScoreAlreadyClaim[pactId][address] indicates how many reward points have
     *      already been claimed by an address for a given pact.
     */
    mapping(uint => mapping(address => uint)) internal prizeScoreAlreadyClaim;

    /**
     * @dev claimedPercentage[pactId][address] tracks the percentage (out of 100) of
     *      reward points claimed by an address for a given pact.
     */
    mapping(uint => mapping(address => uint8)) internal claimedPercentage;

    /**
     * @dev ecosistemAddress[address] marks whether an address belongs to the “ecosystem”
     *      (exempt from certain fees or special rules).
     */
    mapping(address => bool) internal ecosistemAddress;

    /**
     * @dev firstTransfer[pactId] indicates whether the next transfer for a pact must go
     *      to the launcher contract (enforcing a “first transfer” rule).
     */
    mapping(uint => bool) internal firstTransfer;

    /**
     * @dev Tracks the contract’s collected fees for each ERC20 token.
     *      Key:   The token's address.
     *      Value: The total amount of that token held by the contract as fees.
     */
    mapping(address => uint) internal balanceContractFeesForToken;

    /**
     * @dev Tracks the per-pact collateral liquidation factor.
     *
     * This mapping stores the calculated collateral amount per token unit
     * in case of liquidation. It is set only when the first liquidation
     * event occurs for a pact and remains fixed for subsequent liquidations.
     *
     * Key Use Case:
     * - Helps determine how much collateral each pact unit is worth during liquidation.
     */
    mapping(uint => uint) internal liquidationFactor;

    /**
     * @dev Stores the maximum allowable interest deposit for each pact.
     *
     * This value is calculated only after the first deposit of interest tokens
     * and represents the total amount that can be deposited throughout the pact's lifecycle.
     *
     * Key Use Case:
     * - Prevents over-depositing beyond the required interest payments.
     */
    mapping(uint => uint) internal maxInterestDeposit;

    /**
     * @dev Indicates whether the interest deposit window for a pact is closed.
     *
     * This flag is set to `true` once the maximum required interest deposit has been reached,
     * ensuring that no further deposits can be made.
     *
     * Key Use Case:
     * - Enforces that issuers only deposit the exact interest required and prevents excess deposits.
     */
    mapping(uint => bool) internal depositIsClose;


    address immutable internal IHelperPactAddres;



    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant ACCOUNTANT_ROLE = keccak256("ACCOUNTANT_ROLE");
}
