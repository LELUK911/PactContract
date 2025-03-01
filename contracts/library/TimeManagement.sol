// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.24;

library TimeManagment{
    


    function convertDaysInSeconds(uint _days) internal pure returns (uint){
        uint _seconds = _days * 1 days;
        return _seconds;
    }

    function checkDatalistAndExpired(uint64[] memory dataList, uint64 expireData) internal view returns (bool){
        uint64 actualData = uint64(block.timestamp);
        for(uint i=1; i < dataList.length;i++){

            if(dataList[i]<= actualData){
                return false;
            }

            if(i>0 && dataList[i]<= dataList[i-1]){
                return false;
            }
        }
        if(expireData < dataList[dataList.length-1]){
            return false;
        }
        return true;
    }

}