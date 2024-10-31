// SPDX-License-Identifier: Leluk911
pragma solidity ^0.8.24;

contract Logic {
    struct Bond {
        uint id;
        uint[] sistCoupons;
        uint coupon;
    }

    mapping(uint => Bond) public bond;

    uint public counter = 0;

    function setNewCoupon(uint[] memory _listCoupons, uint coupon) public {
        bond[0] = Bond(counter, _listCoupons, coupon);
        counter += 1;
    }

    /*
    struct ReportBuy{
        uint[] data;
        uint[] qta;
    }

    mapping (uint=>mapping(address=>ReportBuy)) internal UserReportBuy;
    
    
    struct ReportSell{
        uint[] data;
        uint[] qta;
    }

    mapping (uint=>mapping(address=>ReportSell)) internal UserReportSell;



    function addBuyOrder(uint _id,uint _data,uint _qta,address _user) public {
        uint[] storage data_ = UserReportBuy[_id][_user].data;
        uint[] storage qta_ = UserReportBuy[_id][_user].qta;

        data_.push(_data);
        qta_.push(_qta);


    }


    function addSellOrder(uint _id,uint _data,uint _qta,address _user) public {
        uint[] storage data_ = UserReportSell[_id][_user].data;
        uint[] storage qta_ = UserReportSell[_id][_user].qta;

        data_.push(_data);
        qta_.push(_qta);


    }


    function calculationQtaCouponPay(uint _id,address _user,uint _coupon) public view returns(uint){
        uint dataTimeOfReferenc = bond[_id].sistCoupons[_coupon];
        uint moltiplicatorCoupon = 0;

        for (uint i=0; i < UserReportBuy[_id][_user].data.length;i++){
            if(UserReportBuy[_id][_user].data[i] < dataTimeOfReferenc){
                moltiplicatorCoupon += UserReportBuy[_id][_user].qta[i];
            }
        }
        for (uint i=0; i < UserReportSell[_id][_user].data.length;i++){
            if(UserReportSell[_id][_user].data[i] < dataTimeOfReferenc){
                moltiplicatorCoupon -= UserReportSell[_id][_user].qta[i];
            }
        }
        return moltiplicatorCoupon;
    }


    */

    mapping(uint => mapping(address => mapping(uint => uint))) couponToClaim;

    function upDateCouponBuy(uint _id, address _user, uint qty) public {
        uint time = block.timestamp;
        for (uint i = 0; i < bond[_id].sistCoupons.length; i++) {
            if (time < bond[_id].sistCoupons[i]) {
                couponToClaim[_id][_user][i] += qty;
            }
        }
    }
    function upDateCouponSell(uint _id, address _user, uint qty) public {
        uint time = block.timestamp;
        for (uint i = 0; i < bond[_id].sistCoupons.length; i++) {
            if (time < bond[_id].sistCoupons[i]) {
                couponToClaim[_id][_user][i] -= qty;
            }
        }
    }

    function claimCoupon(uint _id, address _user, uint _indexCoupon) public {
        uint moltiplicator = couponToClaim[_id][_user][_indexCoupon];
        couponToClaim[_id][_user][_indexCoupon] = 0;
        uint qtaToCouponClaim = moltiplicator * bond[_id].coupon;

        // LOGICA CONTROLLO CAPITALE DISPONIBILE PER IL PAGAMENTO DELLE CEDOLE
        // LOGICA LIQUIDAZIONE PARZIALE
        // INVIO TOKEN
    }
}
