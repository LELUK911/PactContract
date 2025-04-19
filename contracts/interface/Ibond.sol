// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.24;

interface IBondContract {
    struct Pact {
        uint id;
        address debtor;
        address tokenLoan;
        uint sizeLoan;
        uint interest;
        uint[] rewardMaturity;
        //uint numberOfCoupon;
        uint expiredPact;
        address tokenCollateral;
        uint collateral;
        uint balancLoanRepay;
        string describes;
        uint amount;
    }

    // EVENTS
    event SafeTransferFrom(
        address indexed from,
        address indexed to,
        uint indexed id,
        uint256 value
    );
    event SafeBatchTransferFrom(
        address indexed from,
        address indexed to,
        uint[] ids,
        uint256[] values
    );
    event PactCreated(uint indexed id, address indexed debtor, uint amount);
    event CollateralDeposited(
        address indexed debtor,
        uint indexed id,
        uint amount
    );
    event CollateralWithdrawn(
        address indexed debtor,
        uint indexed id,
        uint amount
    );
    event InterestDeposited(
        address indexed debtor,
        uint indexed id,
        uint amount
    );
    event RewardClaimed(address indexed user, uint indexed id, uint amount);
    event LoanClaimed(address indexed user, uint indexed id, uint amount);
    event ScoreUpdated(address indexed debtor, uint newScore);
    event PaidFeeAtContract(address indexed token, uint indexed amount);
    event WitrawBalanceContracr(address indexed token, uint indexed amount);
    event LiquidationReward(
        address indexed user,
        uint indexed id,
        uint indexed amount
    );
    event LiquidationPact(uint indexed id, uint amount);

    // FUNCTIONS

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function viewPactID() external view returns (uint);


    function totalSupply(uint256 id) external view returns (uint256);

    function createNewPact(
        address _debtor,
        address _tokenLoan,
        uint _sizeLoan,
        uint _interest,
        uint[] memory _rewardMaturity,
        uint _expiredPact,
        address _tokenCollateral,
        uint _collateral,
        uint _amount,
        string calldata _describes
    ) external;

    function showDeatailPactForId(uint _id) external view returns (Pact memory);

    function claimRewardForUSer(uint _id, uint _indexReward) external;

    function claimLoan(uint _id, uint _amount) external;

    function depositTokenForInterest(uint _id, uint _amount) external;

    function withdrawCollateral(uint _id) external;

    function claimScorePoint(uint _id) external;

    function setInPause() external;

    function setUnPause() external;

    function withdrawContractBalance(address _tokenAddress) external;
}
