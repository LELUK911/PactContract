// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.22;

interface IHelperBond {
    function newBondChecker(
        uint8 MAX_COUPONS,
        uint64[] memory _couponMaturity,
        uint64 _expiredBond,
        address _tokenLoan,
        address _tokenCollateral,
        uint _sizeLoan,
        uint _interest,
        uint _collateral,
        uint _amount
    ) external view ;
}
