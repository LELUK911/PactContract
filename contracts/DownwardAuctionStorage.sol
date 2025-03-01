// SPDX-License-Identifier: Leluk911

pragma solidity ^0.8.24;


// Contract for managing the storage layer of the downward auction system.
contract DownwardAuctionStorage {
    // Address of the ERC1155 bond contract.
    address internal bondContract;
    // Address of the ERC20 token accepted for payments (to be decided between WETH, USDC, etc.).
    address internal money; 
    // Minimum duration for an auction (7 days in seconds).
    uint internal constant minPeriodAuction = 7 days;
    // Contract balance accumulated from fees.
    uint internal contractBalance;
    // Cooldown period to prevent spamming of operations.
    uint internal coolDown;

    address internal treasury;

    // Structure to represent an auction.
    struct Auction {
        address owner;             // Owner of the auction.
        uint id;                   // ID of the bond being sold.
        uint amount;               // Quantity of bonds put up for auction.
        uint startPrice;           // Starting price of the auction.
        uint expired;              // Expiration timestamp of the auction.
        uint pot;                  // Latest valid bid in the auction.
        address player;            // Last participant who placed a valid bid.
        bool open;                 // Status of the auction (open/closed).
        uint tolleratedDiscount;   // Percentage of tolerated discount on bids.
        uint[] penality;           // List of penalties applied during the auction.
    }

    // Structure for the system's fee configuration.
    struct FeeSystem {
        uint fixedFee;          // Fixed fee for operations.
        uint priceThreshold;    // Threshold for applying a dynamic fee.
        uint dinamicFee;        // Percentage of dynamic fee applied above the threshold.
    }

    // Structure for managing seller fees.
    struct FeeSeller {
        uint[] echelons;        // Price levels for fee application.
        uint[] fees;            // Fee percentages corresponding to each price level.
    }

    // Object representing the general fee system.
    FeeSeller internal feeSeller;
    FeeSystem internal feeSystem;
    // Array containing all active or concluded auctions.
    Auction[] internal auctions;

    // Constant for the fee applied when exceeding the maximum penalty limit.
    uint internal constant OVER_PENALTY_FEE_PERCENTAGE = 3000; // 30%
    // Maximum number of penalties allowed for each auction.
    uint internal constant MAX_PENALTY_ENTRIES = 6;

    // Mapping to track the total balance (including locked funds) for each user.
    mapping(address => uint) balanceUser;
    // Mapping to track the locked funds for each user.
    mapping(address => uint) lockBalance;
    // Mapping to track the timestamp of the last bid made by a user on a specific auction.
    mapping(address => mapping(uint => uint)) internal lastPotTime;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant ACCOUNTANT_ROLE = keccak256("ACCOUNTANT_ROLE");

}
