// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.24;


import {TimeManagment} from "./TimeManagement.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract HelperPact {


        /**
     * @dev Basic check to see if a given address looks like an ERC20 contract.
     *      1) Ensures the address has contract code.
     *      2) Attempts to call `totalSupply()`; if it succeeds, it's likely ERC20.
     */
    function _thisIsERC20(address _addr) internal view returns (bool) {
        try IERC20(_addr).balanceOf(address(this)) returns (uint256) {
            return true;
        } catch {
            return _addr.code.length > 0;
        }
    }



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
        )external view {

        require(_thisIsERC20(_tokenLoan), "Set correct address for Token Loan");
        require(_sizeLoan > 0, "set correct size Loan for variables");
        require(_interest > 0, "set correct Reward for variables");
        require(_collateral > 0, "set correct Collateral for variables");
        require(_amount > 0, "set correct amount for variables");
        require(_rewardMaturity.length <= MAX_REWARDS, "Too many rewards");
        require(
            _tokenCollateral != _tokenLoan,
            "Set different Token Loan and Collateral"
        );

        // Validate scheduled reward schedule and final expiry
        require(
            TimeManagment.checkDatalistAndExpired(
                _rewardMaturity,
                _expiredPact
            ),
            "Set correct data, scheduled reward maturity must be ascending; last < expiredPact"
        );
        require(
            _expiredPact > _rewardMaturity[_rewardMaturity.length - 1],
            "Set correct expiry for this pact"
        );
        require(_amount <= 1000000, "Amount exceeds max pact supply");
        

        }
}