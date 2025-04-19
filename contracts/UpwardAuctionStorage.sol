// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.24;

/**
 * @title UpwardAuctionStorage
 * @dev Storage structure for the UpwardAuction contract, containing all variables and data mappings necessary for the auction system.
 */
contract UpwardAuctionStorage {
    // Address of the ERC1155 pact contract.
    address internal pactContract;

    // Address of the payment token contract (e.g., WETH or USDC).
    address internal money;

    // Minimum period an auction can last.
    uint internal constant minPeriodAuction = 7 days;

    // Contract's total accumulated balance (fees collected).
    uint internal contractBalance;

    // Cooldown period between successive bids for a specific user and auction.
    uint internal coolDown;

    // Maximum allowed increment for a pot as a percentage (e.g., 150% of the current pot).
    uint immutable MAX_POT_MULTIPLIER = 150;

    /**
     * @dev Represents an individual auction.
     * @param owner Address of the user who created the auction.
     * @param id Unique identifier of the pact being auctioned.
     * @param amount Number of pact units available in the auction.
     * @param startPrice Starting price of the auction.
     * @param expired Timestamp when the auction expires.
     * @param pot Current highest bid in the auction.
     * @param player Address of the current highest bidder.
     * @param open Boolean indicating if the auction is still open.
     */
    struct Auction {
        address owner;
        uint id;
        uint amount;
        uint startPrice;
        uint expired;
        uint pot;
        address player;
        bool open;
    }

    /**
     * @dev Represents the system fees configuration.
     * @param fixedFee Fixed fee applied to transactions below the price threshold.
     * @param priceThreshold Price above which dynamic fees are applied.
     * @param dinamicFee Percentage-based fee applied to transactions above the price threshold.
     */
    struct FeeSystem {
        uint fixedFee;
        uint priceThreshold;
        uint dinamicFee;
    }

    /**
     * @dev Represents the seller fee structure for auctions.
     * @param echelons Array of price thresholds for different fee tiers.
     * @param fees Array of corresponding fees for each echelon.
     */
    struct FeeSeller {
        uint[] echelons;
        uint[] fees;
    }

    // Fee structure for sellers.
    FeeSeller internal feeSeller;

    // General fee system configuration.
    FeeSystem internal feeSystem;

    // List of all active auctions.
    Auction[] internal auctions;

    // Mapping to track the balance of each user in the contract.
    mapping(address => uint) balanceUser;

    // Mapping to track the locked balance of each user (e.g., due to ongoing auctions).
    mapping(address => uint) lockBalance;

    // Mapping to track the last bid time for each user and auction (used for cooldown enforcement).
    mapping(address => mapping(uint => uint)) internal lastPotTime;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant ACCOUNTANT_ROLE = keccak256("ACCOUNTANT_ROLE");
address internal treasury;
}
