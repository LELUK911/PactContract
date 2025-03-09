// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.24;


import {TimeManagment} from "./TimeManagement.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract HelperBond {


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
        )external view {

        require(_thisIsERC20(_tokenLoan), "Set correct address for Token Loan");
        require(_sizeLoan > 0, "set correct size Loan for variables");
        require(_interest > 0, "set correct Interest for variables");
        require(_collateral > 0, "set correct Collateral for variables");
        require(_amount > 0, "set correct amount for variables");
        require(_couponMaturity.length <= MAX_COUPONS, "Too many coupons");
        require(
            _tokenCollateral != _tokenLoan,
            "Set different Token Loan and Collateral"
        );

        // Validate coupon schedule and final expiry
        require(
            TimeManagment.checkDatalistAndExpired(
                _couponMaturity,
                _expiredBond
            ),
            "Set correct data, coupon maturity must be ascending; last < expiredBond"
        );
        require(
            _expiredBond > _couponMaturity[_couponMaturity.length - 1],
            "Set correct expiry for this bond"
        );
        require(_amount <= 1000000, "Amount exceeds max bond supply");
        

        }
}