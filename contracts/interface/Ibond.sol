// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.24;

interface IBondContract {
    struct Bond {
        uint id;
        address issuer;
        address tokenLoan;
        uint sizeLoan;
        uint interest;
        uint[] couponMaturity;
        //uint numberOfCoupon;
        uint expiredBond;
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
    event BondCreated(uint indexed id, address indexed issuer, uint amount);
    event CollateralDeposited(
        address indexed issuer,
        uint indexed id,
        uint amount
    );
    event CollateralWithdrawn(
        address indexed issuer,
        uint indexed id,
        uint amount
    );
    event InterestDeposited(
        address indexed issuer,
        uint indexed id,
        uint amount
    );
    event CouponClaimed(address indexed user, uint indexed id, uint amount);
    event LoanClaimed(address indexed user, uint indexed id, uint amount);
    event ScoreUpdated(address indexed issuer, uint newScore);
    event PaidFeeAtContract(address indexed token, uint indexed amount);
    event WitrawBalanceContracr(address indexed token, uint indexed amount);
    event LiquidationCoupon(
        address indexed user,
        uint indexed id,
        uint indexed amount
    );
    event LiquidationBond(uint indexed id, uint amount);

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

    function viewBondID() external view returns (uint);


    function totalSupply(uint256 id) external view returns (uint256);

    function createNewBond(
        address _issuer,
        address _tokenLoan,
        uint _sizeLoan,
        uint _interest,
        uint[] memory _couponMaturity,
        uint _expiredBond,
        address _tokenCollateral,
        uint _collateral,
        uint _amount,
        string calldata _describes
    ) external;

    function showDeatailBondForId(uint _id) external view returns (Bond memory);

    function claimCouponForUSer(uint _id, uint _indexCoupon) external;

    function claimLoan(uint _id, uint _amount) external;

    function depositTokenForInterest(uint _id, uint _amount) external;

    function withdrawCollateral(uint _id) external;

    function claimScorePoint(uint _id) external;

    function setInPause() external;

    function setUnPause() external;

    function withdrawContractBalance(address _tokenAddress) external;
}
