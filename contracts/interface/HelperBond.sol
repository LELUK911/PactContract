// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.22;

interface IHelperPact {
    function newPactChecker(
        uint8 MAX_REWARDS,
        uint64[] memory _rewardMaturity,
        uint64 _expiredPact,
        address _tokenLoan,
        address _tokenCollateral,
        uint _sizeLoan,
        uint _interest,
        uint _collateral,
        uint _amount
    ) external view ;
}
