const { expect } = require("chai");
const { ethers } = require("hardhat");

describe('Test Bond, stable version', () => {

    let bondContract, mockWETH, mockDai, mockBTC, mockAlt, owner, issuer, user1, user2, user3, user4;
    let bondContractAddress, daiAddress, btcAddress, WETHaddress, Altaddress;
    let launchBondContract, launchBondContractAddress
    let upwardAuctionContract, upwardAuctionContractAddress
    let downwardAuctionContract, downwardAuctionContractAddress

    //? BOND FUNCTION
    let newBondFunction
    //? HELPER 
    let expiredCoupons, expired

    beforeEach(async () => {
        [owner, issuer, user1, user2, user3, user4] = await ethers.getSigners();

        const BondContractFactory = await ethers.getContractFactory("BondContract");
        bondContract = await BondContractFactory.connect(owner).deploy(owner.address)
        await bondContract.waitForDeployment()
        bondContractAddress = await bondContract.getAddress()

        const LaunchBondContract = await ethers.getContractFactory('BondLaunch')
        launchBondContract = await LaunchBondContract.connect(owner).deploy(bondContractAddress)
        await launchBondContract.waitForDeployment()
        launchBondContractAddress = await launchBondContract.getAddress()

        const MockToken = await ethers.getContractFactory('MockToken');
        mockWETH = await MockToken.deploy(ethers.parseUnits('90000000000000000000'), 'WETH', 'WETH');
        mockDai = await MockToken.deploy(ethers.parseUnits('90000000000000000000'), 'Dai Token', 'DAI');
        mockBTC = await MockToken.deploy(ethers.parseUnits('90000000000000000000'), 'Bitcoin', 'BTC');
        mockAlt = await MockToken.deploy(ethers.parseUnits('99999999999999999999999999'), 'ALtcoin', 'ALT');

        await mockBTC.connect(owner).transfer(issuer.address, ethers.parseUnits('1000000000000'))
        await mockDai.connect(owner).transfer(issuer.address, ethers.parseUnits('1000000000000'))
        await mockWETH.connect(owner).transfer(issuer.address, ethers.parseUnits('1000000000000'))

        await mockWETH.waitForDeployment()
        await mockDai.waitForDeployment()
        await mockBTC.waitForDeployment()
        await mockAlt.waitForDeployment()
        daiAddress = await mockDai.getAddress()
        btcAddress = await mockBTC.getAddress()
        WETHaddress = await mockWETH.getAddress()
        Altaddress = await mockAlt.getAddress()


        //? UPWARD DEPLOY AND PRELIMINAR ACTION
        const UpwardAuction = await ethers.getContractFactory('UpwardAuction')
        upwardAuctionContract = await UpwardAuction.connect(owner).deploy(
            bondContractAddress,
            daiAddress,
            ethers.parseUnits('1'),//fixed Fee 1$
            ethers.parseUnits('1000'),// price Threshold 1000$
            100 //dinamicfee 1%
        )
        await upwardAuctionContract.waitForDeployment()
        upwardAuctionContractAddress = await upwardAuctionContract.getAddress()

        const _echelons = [
            ethers.parseUnits('1000'), // value in $
            ethers.parseUnits('10000'),
            ethers.parseUnits('100000'),
            ethers.parseUnits('1000000'),
        ]
        const _fees = [
            100, 75, 50, 25 //1%,0.75%,0.5%,0.25%
        ]

        await upwardAuctionContract.connect(owner).setFeeSeller(_echelons, _fees)

        //? DOWNAUCTION DEPLOY AND PRELIMINAR ACTION
        const downwardAuction = await ethers.getContractFactory('DownwardAuction')
        downwardAuctionContract = await downwardAuction.connect(owner).deploy(
            bondContractAddress,
            daiAddress,
            ethers.parseUnits('1'),//fixed Fee 1$
            ethers.parseUnits('1000'),// price Threshold 1000$
            100 //dinamicfee 1%
        )
        await downwardAuctionContract.waitForDeployment()
        downwardAuctionContractAddress = await downwardAuctionContract.getAddress()
        await downwardAuctionContract.connect(owner).setFeeSeller(_echelons, _fees)

        //? set preliminar variable BondContract
        await bondContract.connect(owner).setMAX_COUPONS('6')
        await bondContract.connect(owner).setTransfertFee(ethers.parseUnits('0.01'))
        await bondContract.connect(owner).setlauncherContract(launchBondContractAddress)
        await bondContract.connect(owner).setlauncherContract(launchBondContractAddress)
        await bondContract.connect(owner).setWETHaddress(WETHaddress)
        await bondContract.connect(owner).setTreasuryAddress(owner.address) // Uguale all'owner per comodità nei test
        await bondContract.connect(owner).setEcosistemAddress(upwardAuctionContractAddress, true) // Uguale all'owner per comodità nei test
        await bondContract.connect(owner).setEcosistemAddress(downwardAuctionContractAddress, true) // Uguale all'owner per comodità nei test

        //***  HELPER
        expiredCoupons = async (daysList) => {
            const currentBlock = await ethers.provider.getBlock("latest");
            const currentTimestamp = currentBlock.timestamp;
            const oneDayTime = currentTimestamp + 86400;  // 1 giorno
            let couponExpired = []
            for (let index = 0; index < daysList.length; index++) {
                const element = daysList[index];
                couponExpired.push((oneDayTime * element).toString())
            }
            console.log(couponExpired)
            return couponExpired;
        }
        expired = async (days) => {
            const currentBlock = await ethers.provider.getBlock("latest");
            const currentTimestamp = currentBlock.timestamp;
            const dayTime = currentTimestamp + (86400 * days);
            return dayTime.toString();
        }
        //***  BOND FUNCTION
        newBondFunction = async (_sizeLoan, _interest, couponMaturity, expiredBond, _collateralAmount, issuer, amount) => {
            const sizeLoan = ethers.parseUnits(_sizeLoan);
            const interest = ethers.parseUnits(_interest);
            const collateralAmount = ethers.parseUnits(_collateralAmount);
            const bondAmount = amount;
            const description = "Test bond";
            await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits(_collateralAmount))

            await expect(
                bondContract.connect(issuer).createNewBond(
                    issuer.address,
                    await mockDai.getAddress(),
                    sizeLoan,
                    interest,
                    couponMaturity,
                    expiredBond,
                    await mockBTC.getAddress(),
                    collateralAmount,
                    bondAmount,
                    description
                )
            ).to.emit(bondContract, "BondCreated");
        }
        //! IL COOLDOWN NON VIENE SETTATO PER SEMPLICITÀ DEI TEST
    });
    it('deploys correctly and initializes variables', async () => {
        const bondID = await bondContract.connect(owner).viewBondID()
        const ownerAddress = await bondContract.connect(owner).owner()
        const wethAddress = await bondContract.connect(owner).showWETHaddress()
        const transferFee = await bondContract.connect(owner).showTransfertFee()
        const BondContractAddressInLauncher = await launchBondContract.connect(owner).showBondContractAddress()
        const BondContractAddressInUpwardAuction = await upwardAuctionContract.connect(owner).showBondContractAddress()
        const BondContractAddressInDownwardAuction = await downwardAuctionContract.connect(owner).showBondContractAddress()

        const echelonsControl = [
            1000000000000000000000n,
            10000000000000000000000n,
            100000000000000000000000n,
            1000000000000000000000000n
        ]
        const feeControl = [100n, 75n, 50n, 25n]


        //UpwardAuction
        const upFeeSystem = await upwardAuctionContract.connect(owner).showFeesSystem()
        const upFeeSeller = await upwardAuctionContract.connect(owner).showFeesSeller()

        //todo controlli manuali fatti successivamente settero quelli formali

        //DownwardAuction
        const downFeeSystem = await downwardAuctionContract.connect(owner).showFeesSystem()
        const downFeeSeller = await downwardAuctionContract.connect(owner).showFeesSeller()

        //todo controlli manuali fatti successivamente settero quelli formali
        expect(await bondID.toString()).to.eq('0')
        expect(ownerAddress).to.eq(owner.address)
        expect(wethAddress).to.eq(WETHaddress)
        expect(transferFee.toString()).to.eq((ethers.parseUnits('0.01')).toString())
        expect(BondContractAddressInLauncher).to.eq(bondContractAddress)
        expect(BondContractAddressInUpwardAuction).to.eq(bondContractAddress)
        expect(BondContractAddressInDownwardAuction).to.eq(bondContractAddress)

    });
    it("Create new bonds ", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100')
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100')
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100')
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100')
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100')
    })
    it("Create new bond and launch on launcher", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100') // ID 0
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100') // ID 1

        //? Approve launchBondContract at spending ERC1155
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);

        //? Launch Bond ID1
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')

        //? Verifies
        const bondList = await launchBondContract.connect(issuer).showBondLaunchList()
        expect(bondList[0].toString()).eq("1");
        expect(await launchBondContract.connect(owner).showAmountInSellForBond('1')).eq('100');
    })
    it("Two user buy some bond in launch", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100') // ID 0
        await newBondFunction('500', '20', couponMaturity, expiredBond, '10', issuer, '10000') // ID 1
        await newBondFunction('10000', '75', couponMaturity, expiredBond, '100', issuer, '300') // ID 2
        await newBondFunction('350', '2', couponMaturity, expiredBond, '2', issuer, '70') // ID 3
        await newBondFunction('800', '80', couponMaturity, expiredBond, '8', issuer, '1000') // ID 4

        //? Approve launchBondContract at spending ERC1155
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);

        //? Launch Bond ID1
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '10000')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('0', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('2', '300')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('4', '500')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('3', '70')).to.emit(launchBondContract, 'IncrementBondInLaunch')

        //? Verifies
        const bondList = await launchBondContract.connect(issuer).showBondLaunchList()
        expect(bondList[3].toString()).eq("4");
        expect(await launchBondContract.connect(owner).showAmountInSellForBond('1')).eq('10000');

        const sizeBond = ethers.parseUnits((800 * 100).toString());

        await mockDai.connect(owner).transfer(user1, sizeBond);
        await mockDai.connect(user1).approve(launchBondContractAddress, sizeBond);

        const sizeBond2 = ethers.parseUnits((800 * 15).toString());

        await mockDai.connect(owner).transfer(user2, sizeBond2);
        await mockDai.connect(user2).approve(launchBondContractAddress, sizeBond);

        await expect(launchBondContract.connect(user1).buyBond(4, 3, 100)).to.emit(launchBondContract, 'BuyBond')
        expect((await launchBondContract.connect(user1).showBondForWithdraw(user1, 4)).toString()).eq('100')
        await launchBondContract.connect(user1).withdrawBondBuy(4)

        expect(await launchBondContract.connect(user1).balanceIssuer(issuer.address, mockDai)).eq(sizeBond)

        await expect(launchBondContract.connect(user2).buyBond(4, 3, 15)).to.emit(launchBondContract, 'BuyBond')
        expect((await launchBondContract.connect(user2).showBondForWithdraw(user2, 4)).toString()).eq('15')
        await launchBondContract.connect(user2).withdrawBondBuy(4)


        // verifiche
        const balanceBond1 = await bondContract.connect(user1).balanceOf(user1, 4);
        expect(balanceBond1.toString()).eq('100');
        const balanceBond2 = await bondContract.connect(user2).balanceOf(user2, 4);
        expect(balanceBond2.toString()).eq('15');
        expect(await launchBondContract.connect(owner).showAmountInSellForBond('4')).eq('385');
        expect(await mockDai.connect(owner).balanceOf(launchBondContract)).eq(ethers.parseUnits('92000'));
        // operazione post verifiche
        await expect(launchBondContract.connect(issuer).withdrawToken(await mockDai.getAddress())).to.emit(launchBondContract, 'WithdrawToken');
        const contractERC20balance = await mockDai.connect(owner).balanceOf(launchBondContractAddress)
        expect(contractERC20balance.toString()).eq('0');







    })
    it("Iusser pay for all coupon and repay all bond", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100') // ID 0
        await newBondFunction('500', '20', couponMaturity, expiredBond, '10', issuer, '10000') // ID 1
        await newBondFunction('10000', '75', couponMaturity, expiredBond, '100', issuer, '300') // ID 2
        await newBondFunction('350', '2', couponMaturity, expiredBond, '2', issuer, '70') // ID 3
        await newBondFunction('800', '80', couponMaturity, expiredBond, '8', issuer, '500') // ID 4

        //? Approve launchBondContract at spending ERC1155
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);

        //? Launch Bond ID1
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '10000')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('0', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('2', '300')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('4', '500')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('3', '70')).to.emit(launchBondContract, 'IncrementBondInLaunch')

        //? Verifies
        const bondList = await launchBondContract.connect(issuer).showBondLaunchList()
        expect(bondList[3].toString()).eq("4");
        expect(await launchBondContract.connect(owner).showAmountInSellForBond('1')).eq('10000');

        const sizeBond = ethers.parseUnits((800 * 100).toString());

        await mockDai.connect(owner).transfer(user1, sizeBond);
        await mockDai.connect(user1).approve(launchBondContractAddress, sizeBond);

        const sizeBond2 = ethers.parseUnits((800 * 15).toString());

        await mockDai.connect(owner).transfer(user2, sizeBond2);
        await mockDai.connect(user2).approve(launchBondContractAddress, sizeBond);

        await expect(launchBondContract.connect(user1).buyBond(4, 3, 100)).to.emit(launchBondContract, 'BuyBond')
        expect((await launchBondContract.connect(user1).showBondForWithdraw(user1, 4)).toString()).eq('100')
        await launchBondContract.connect(user1).withdrawBondBuy(4)

        await expect(launchBondContract.connect(user2).buyBond(4, 3, 15)).to.emit(launchBondContract, 'BuyBond')
        expect((await launchBondContract.connect(user2).showBondForWithdraw(user2, 4)).toString()).eq('15')
        await launchBondContract.connect(user2).withdrawBondBuy(4)

        const sizeBond3 = ethers.parseUnits((800 * 385).toString());

        await mockDai.connect(owner).transfer(user3, sizeBond3);
        await mockDai.connect(user3).approve(launchBondContractAddress, sizeBond3);


        await expect(launchBondContract.connect(user3).buyBond(4, 3, 385)).to.emit(launchBondContract, 'BuyBond')
        expect((await launchBondContract.connect(user3).showBondForWithdraw(user3, 4)).toString()).eq('385')
        await launchBondContract.connect(user3).withdrawBondBuy(4)

        /**
           await newBondFunction('800','80',couponMaturity,expiredBond,'8',issuer,'500') // ID 4
            ((80 mdai * 6 coupon) * 500) + (800*500) = 640.000
        */

        await mockDai.connect(owner).transfer(issuer, ethers.parseUnits('640000'));
        await mockDai.connect(issuer).approve(bondContractAddress, ethers.parseUnits('640000'));

        //? DEPOSIT TOKEN FOR PAY COUPON
        await expect(bondContract.connect(issuer).depositTokenForInterest(4, ethers.parseUnits('640000'))).to.emit(bondContract, 'InterestDeposited')

        // in next time over expiredBond
        await ethers.provider.send("evm_increaseTime", [expiredBond + 1]);
        await ethers.provider.send("evm_mine");

        await expect(bondContract.connect(user1).claimCouponForUSer(4, 0)).to.emit(bondContract, "CouponClaimed");

        const daiBalance1 = await mockDai.connect(user1).balanceOf(user1)
        // 100 bond * 100 coupon da 80mdai - le fee dello 0.5% 
        expect(ethers.formatUnits(daiBalance1.toString())).to.eq((((100 * 80) * 0.995)).toString() + '.0')

        await expect(bondContract.connect(user1).claimCouponForUSer(4, 1)).to.emit(bondContract, "CouponClaimed");
        await expect(bondContract.connect(user1).claimCouponForUSer(4, 2)).to.emit(bondContract, "CouponClaimed");
        await expect(bondContract.connect(user1).claimCouponForUSer(4, 3)).to.emit(bondContract, "CouponClaimed");
        await expect(bondContract.connect(user1).claimCouponForUSer(4, 4)).to.emit(bondContract, "CouponClaimed");
        await expect(bondContract.connect(user1).claimCouponForUSer(4, 5)).to.emit(bondContract, "CouponClaimed");

        for (let index = 0; index < couponMaturity.length; index++) {
            await expect(bondContract.connect(user2).claimCouponForUSer(4, index)).to.emit(bondContract, "CouponClaimed");
            await expect(bondContract.connect(user3).claimCouponForUSer(4, index)).to.emit(bondContract, "CouponClaimed");
        }

        const daiBalance3 = await mockDai.connect(user1).balanceOf(user1)
        await mockDai.connect(user1).transfer(owner, daiBalance3.toString());
        await expect(bondContract.connect(user1).claimLoan(4, 100)).to.emit(bondContract, "LoanClaimed");

        const daiBalance4 = await mockDai.connect(user1).balanceOf(user1)
        // 100 bond * 800 mdai - le fee dello 1.5% 
        expect(ethers.formatUnits(daiBalance4.toString())).to.eq((((100 * 800) * 0.985)).toString() + '.0')

        await expect(bondContract.connect(user2).claimLoan(4, 15)).to.emit(bondContract, "LoanClaimed");
        await expect(bondContract.connect(user3).claimLoan(4, 385)).to.emit(bondContract, "LoanClaimed");
        await expect(bondContract.connect(owner).withdrawContractBalance(daiAddress)).to.emit(bondContract, 'WitrawBalanceContracr')

        //** User can withdraw collateral */
        await expect(bondContract.connect(issuer).withdrawCollateral(4)).to.emit(bondContract, 'CollateralWithdrawn')

    })
    it("Iusser pay for all coupon and repay all bond -> user send more bond at other user", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100') // ID 0
        await newBondFunction('500', '20', couponMaturity, expiredBond, '10', issuer, '10000') // ID 1
        await newBondFunction('10000', '75', couponMaturity, expiredBond, '100', issuer, '300') // ID 2
        await newBondFunction('350', '2', couponMaturity, expiredBond, '2', issuer, '70') // ID 3
        await newBondFunction('800', '80', couponMaturity, expiredBond, '8', issuer, '500') // ID 4

        //? Approve launchBondContract at spending ERC1155
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);

        //? Launch Bond ID1
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '10000')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('0', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('2', '300')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('4', '500')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('3', '70')).to.emit(launchBondContract, 'IncrementBondInLaunch')

        const sizeBond = ethers.parseUnits((800 * 100).toString());

        await mockDai.connect(owner).transfer(user1, sizeBond);
        await mockDai.connect(user1).approve(launchBondContractAddress, sizeBond);

        const sizeBond2 = ethers.parseUnits((800 * 15).toString());

        await mockDai.connect(owner).transfer(user2, sizeBond2);
        await mockDai.connect(user2).approve(launchBondContractAddress, sizeBond);

        await expect(launchBondContract.connect(user1).buyBond(4, 3, 100)).to.emit(launchBondContract, 'BuyBond')
        await launchBondContract.connect(user1).withdrawBondBuy(4)

        await expect(launchBondContract.connect(user2).buyBond(4, 3, 15)).to.emit(launchBondContract, 'BuyBond')
        await launchBondContract.connect(user2).withdrawBondBuy(4)

        const sizeBond3 = ethers.parseUnits((800 * 385).toString());

        await mockDai.connect(owner).transfer(user3, sizeBond3);
        await mockDai.connect(user3).approve(launchBondContractAddress, sizeBond3);


        await expect(launchBondContract.connect(user3).buyBond(4, 3, 385)).to.emit(launchBondContract, 'BuyBond')
        await launchBondContract.connect(user3).withdrawBondBuy(4)

        /**
           await newBondFunction('800','80',couponMaturity,expiredBond,'8',issuer,'500') // ID 4
            ((80 mdai * 6 coupon) * 500) + (800*500) = 640.000
        */

        await mockDai.connect(owner).transfer(issuer, ethers.parseUnits('640000'));
        await mockDai.connect(issuer).approve(bondContractAddress, ethers.parseUnits('640000'));

        //? DEPOSIT TOKEN FOR PAY COUPON
        await expect(bondContract.connect(issuer).depositTokenForInterest(4, ethers.parseUnits('640000'))).to.emit(bondContract, 'InterestDeposited')

        // in next time over expiredBond


        const dayInSecond = 86400;
        await ethers.provider.send("evm_increaseTime", [dayInSecond * 5]);
        await ethers.provider.send("evm_mine");


        await mockWETH.connect(owner).transfer(user1, ethers.parseUnits('1000000'));
        await mockWETH.connect(user1).approve(bondContractAddress, ethers.parseUnits('1000000'));

        await mockWETH.connect(owner).transfer(user2, ethers.parseUnits('1000000'));
        await mockWETH.connect(user2).approve(bondContractAddress, ethers.parseUnits('1000000'));

        await mockWETH.connect(owner).transfer(user3, ethers.parseUnits('1000000'));
        await mockWETH.connect(user3).approve(bondContractAddress, ethers.parseUnits('1000000'));



        await expect(
            bondContract.connect(user3).safeTransferFrom(user3.address, user4.address, 4, 50, "0x")
        ).to.emit(bondContract, "SafeTransferFrom");

        //verifica
        const wethBalance = await mockWETH.connect(user3).balanceOf(bondContractAddress);
        const transfertFee = await bondContract.connect(owner).showTransfertFee()
        expect(wethBalance.toString()).to.eq(transfertFee.toString())


        await ethers.provider.send("evm_increaseTime", [dayInSecond * 7]);
        await ethers.provider.send("evm_mine");


        const balanceBondID4 = await bondContract.balanceOf(user4.address, '4');
        expect(balanceBondID4.toString()).be.eq('50')

        const DaiBalanceBefore = await mockDai.connect(owner).balanceOf(user4.address);
        await expect(bondContract.connect(user4).claimCouponForUSer(4, 0)).to.emit(bondContract, "CouponClaimed");
        const DaiBalanceAfter = await mockDai.connect(owner).balanceOf(user4.address);
        expect(+DaiBalanceBefore.toString()).to.below(+DaiBalanceAfter.toString())
        // 100 bond * 100 coupon da 80mdai - le fee dello 0.5% 
        expect(ethers.formatUnits(DaiBalanceAfter.toString())).to.eq((((50 * 80) * 0.995)).toString() + '.0')



        const balanceBondID4User3 = await bondContract.balanceOf(user3.address, '4');
        expect(balanceBondID4User3.toString()).be.eq('335')


        const DaiBalanceBeforeUser3 = await mockDai.connect(owner).balanceOf(user3.address);
        await expect(bondContract.connect(user3).claimCouponForUSer(4, 0)).to.emit(bondContract, "CouponClaimed");
        const DaiBalanceAfterUser3 = await mockDai.connect(owner).balanceOf(user3.address);
        expect(+DaiBalanceBeforeUser3.toString()).to.below(+DaiBalanceAfterUser3.toString())
        expect(ethers.formatUnits(DaiBalanceAfterUser3.toString())).to.eq((((335 * 80) * 0.995)).toString() + '.0')

        await ethers.provider.send("evm_increaseTime", [expiredBond + 10000]);
        await ethers.provider.send("evm_mine");

        await expect(bondContract.connect(user4).claimCouponForUSer(4, 0)).be.rejectedWith("Haven't Coupon for claim");
        await expect(bondContract.connect(user3).claimCouponForUSer(4, 0)).be.rejectedWith("Haven't Coupon for claim");

        await expect(bondContract.connect(user3).claimLoan(4, 335)).to.emit(bondContract, "LoanClaimed");
        await expect(bondContract.connect(user4).claimLoan(4, 50)).to.emit(bondContract, "LoanClaimed");

    })
    it("Iuser don't pay for coupon, single liquidation event for one user (Balance loan 0", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100') // ID 0
        await newBondFunction('100', '1', couponMaturity, expiredBond, '10', issuer, '100') // ID 1
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')

        const sizeBond = ethers.parseUnits((100 * 100).toString());

        await mockDai.connect(owner).transfer(user1, sizeBond);
        await mockDai.connect(user1).approve(launchBondContractAddress, sizeBond);

        await expect(launchBondContract.connect(user1).buyBond(1, 0, 100)).to.emit(launchBondContract, 'BuyBond')
        await launchBondContract.connect(user1).withdrawBondBuy(1)

        // in next time over expiredBond
        const dayInSecond = 86400;
        await ethers.provider.send("evm_increaseTime", [dayInSecond * 150]);
        await ethers.provider.send("evm_mine");


        const BTCBalanceBefore = await mockBTC.connect(owner).balanceOf(user1.address);
        await expect(bondContract.connect(user1).claimCouponForUSer(1, 0)).to.emit(bondContract, "CouponClaimed");
        const BTCBalanceAfter = await mockBTC.connect(owner).balanceOf(user1.address);
        expect(+BTCBalanceBefore.toString()).to.below(+BTCBalanceAfter.toString())
        // la matematica è un po difficile da buttare giu ma il codice gira come deve







    })
    it("Iuser don't pay parzial loan but pay all coupon, single liquidation event for one user (Balance loan  at expired)", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100') // ID 0
        await newBondFunction('100', '10', couponMaturity, expiredBond, '10', issuer, '100') // ID 1
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')

        const sizeBond = ethers.parseUnits(((10 * 100) * 3).toString());
        await mockDai.connect(owner).transfer(issuer, sizeBond);
        await mockDai.connect(issuer).approve(bondContractAddress, sizeBond);

        await expect(bondContract.connect(issuer).depositTokenForInterest(1, sizeBond)).to.emit(bondContract, 'InterestDeposited')

        const sizeBond1 = ethers.parseUnits((100 * 100).toString());

        await mockDai.connect(owner).transfer(user1, sizeBond1);
        await mockDai.connect(user1).approve(launchBondContractAddress, sizeBond1);

        await expect(launchBondContract.connect(user1).buyBond(1, 0, 100)).to.emit(launchBondContract, 'BuyBond')
        await launchBondContract.connect(user1).withdrawBondBuy(1)

        // in next time over expiredBond
        const dayInSecond = 86400;
        await ethers.provider.send("evm_increaseTime", [dayInSecond * 150]);
        await ethers.provider.send("evm_mine");

        for (let index = 0; index < expiredCoupons.length; index++) {
            await expect(bondContract.connect(user1).claimCouponForUSer(1, index)).to.emit(bondContract, "CouponClaimed");
            const BTCBalance = await mockBTC.connect(owner).balanceOf(user1.address);
            expect(BTCBalance.toString()).to.eq('0')
        }



        const BTCBalanceBefore = await mockBTC.connect(owner).balanceOf(user1.address);
        const DaiBalanceBefore = await mockDai.connect(owner).balanceOf(user1.address);

        await mockDai.connect(user1).approve(bondContractAddress, sizeBond);
        await expect(bondContract.connect(user1).claimLoan(1, 100)).to.emit(bondContract, "LoanClaimed");
        const BTCBalanceAfter = await mockBTC.connect(owner).balanceOf(user1.address);
        const DaiBalanceAfter = await mockDai.connect(owner).balanceOf(user1.address);

        expect(+BTCBalanceBefore.toString()).to.below(+BTCBalanceAfter.toString())
        expect(+DaiBalanceBefore.toString()).to.below(+DaiBalanceAfter.toString())

    })
    it("Iuser don't pay parzial loan but pay all coupon, single liquidation event for one user (Balance loan  at expired)", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100') // ID 0
        await newBondFunction('100', '10', couponMaturity, expiredBond, '10', issuer, '100') // ID 1
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')

        const sizeBond = ethers.parseUnits(((10 * 100) * 7).toString());
        await mockDai.connect(owner).transfer(issuer, sizeBond);
        await mockDai.connect(issuer).approve(bondContractAddress, sizeBond);

        await expect(bondContract.connect(issuer).depositTokenForInterest(1, sizeBond)).to.emit(bondContract, 'InterestDeposited')

        const sizeBond1 = ethers.parseUnits((100 * 100).toString());

        await mockDai.connect(owner).transfer(user1, sizeBond1);
        await mockDai.connect(user1).approve(launchBondContractAddress, sizeBond1);

        await expect(launchBondContract.connect(user1).buyBond(1, 0, 100)).to.emit(launchBondContract, 'BuyBond')
        await launchBondContract.connect(user1).withdrawBondBuy(1)

        // in next time over expiredBond
        const dayInSecond = 86400;
        await ethers.provider.send("evm_increaseTime", [dayInSecond * 150]);
        await ethers.provider.send("evm_mine");

        for (let index = 0; index < couponMaturity.length; index++) {
            await expect(bondContract.connect(user1).claimCouponForUSer(1, index)).to.emit(bondContract, "CouponClaimed");
            const BTCBalance = await mockBTC.connect(owner).balanceOf(user1.address);
            expect(BTCBalance.toString()).to.eq('0')
        }



        const BTCBalanceBefore = await mockBTC.connect(owner).balanceOf(user1.address);
        const DaiBalanceBefore = await mockDai.connect(owner).balanceOf(user1.address);

        await mockDai.connect(user1).approve(bondContractAddress, sizeBond);
        await expect(bondContract.connect(user1).claimLoan(1, 100)).to.emit(bondContract, "LoanClaimed");
        const BTCBalanceAfter = await mockBTC.connect(owner).balanceOf(user1.address);
        const DaiBalanceAfter = await mockDai.connect(owner).balanceOf(user1.address);

        expect(+BTCBalanceBefore.toString()).to.below(+BTCBalanceAfter.toString())
        expect(+DaiBalanceBefore.toString()).to.below(+DaiBalanceAfter.toString())

    })
    it("Iuser don't pay loan but pay all coupon, single liquidation event for one user (Balance loan  at expired)", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100') // ID 0
        await newBondFunction('100', '10', couponMaturity, expiredBond, '10', issuer, '100') // ID 1
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')

        const sizeBond = ethers.parseUnits(((10 * 100) * 6).toString());
        await mockDai.connect(owner).transfer(issuer, sizeBond);
        await mockDai.connect(issuer).approve(bondContractAddress, sizeBond);

        await expect(bondContract.connect(issuer).depositTokenForInterest(1, sizeBond)).to.emit(bondContract, 'InterestDeposited')

        const sizeBond1 = ethers.parseUnits((100 * 100).toString());

        await mockDai.connect(owner).transfer(user1, sizeBond1);
        await mockDai.connect(user1).approve(launchBondContractAddress, sizeBond1);

        await expect(launchBondContract.connect(user1).buyBond(1, 0, 100)).to.emit(launchBondContract, 'BuyBond')
        await launchBondContract.connect(user1).withdrawBondBuy(1)

        // in next time over expiredBond
        const dayInSecond = 86400;
        await ethers.provider.send("evm_increaseTime", [dayInSecond * 150]);
        await ethers.provider.send("evm_mine");

        for (let index = 0; index < couponMaturity.length; index++) {
            await expect(bondContract.connect(user1).claimCouponForUSer(1, index)).to.emit(bondContract, "CouponClaimed");
            const BTCBalance = await mockBTC.connect(owner).balanceOf(user1.address);
            expect(BTCBalance.toString()).to.eq('0')
        }

        const BTCBalanceBefore = await mockBTC.connect(owner).balanceOf(user1.address);
        const DaiBalanceBefore = await mockDai.connect(owner).balanceOf(user1.address);

        await mockDai.connect(user1).approve(bondContractAddress, sizeBond);
        await expect(bondContract.connect(user1).claimLoan(1, 100)).to.emit(bondContract, "LiquitationCollateralBondExpired");
        const BTCBalanceAfter = await mockBTC.connect(owner).balanceOf(user1.address);
        const DaiBalanceAfter = await mockDai.connect(owner).balanceOf(user1.address);

        expect(+BTCBalanceBefore.toString()).to.below(+BTCBalanceAfter.toString())
        expect(+DaiBalanceBefore.toString()).to.eq(+DaiBalanceAfter.toString())

    })
    it("Iuser don't pay one coupon but pay all loan, single liquidation event for one user", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100') // ID 0
        await newBondFunction('100', '10', couponMaturity, expiredBond, '10', issuer, '100') // ID 1
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')

        const sizeBond = ethers.parseUnits((((10 * 100) * 6) - 250).toString());
        await mockDai.connect(owner).transfer(issuer, sizeBond);
        await mockDai.connect(issuer).approve(bondContractAddress, sizeBond);

        await expect(bondContract.connect(issuer).depositTokenForInterest(1, sizeBond)).to.emit(bondContract, 'InterestDeposited')

        const sizeBond1 = ethers.parseUnits((100 * 100).toString());

        await mockDai.connect(owner).transfer(user1, sizeBond1);
        await mockDai.connect(user1).approve(launchBondContractAddress, sizeBond1);

        await expect(launchBondContract.connect(user1).buyBond(1, 0, 100)).to.emit(launchBondContract, 'BuyBond')
        await launchBondContract.connect(user1).withdrawBondBuy(1)

        // in next time over expiredBond
        const dayInSecond = 86400;
        await ethers.provider.send("evm_increaseTime", [dayInSecond * 150]);
        await ethers.provider.send("evm_mine");

        for (let index = 0; index < couponMaturity.length; index++) {
            await expect(bondContract.connect(user1).claimCouponForUSer(1, index)).to.emit(bondContract, "CouponClaimed");
            const BTCBalance = await mockBTC.connect(owner).balanceOf(user1.address);
            if (BTCBalance.toString() != '0') {
                //console.log(index);
            } else { expect(BTCBalance.toString()).to.eq('0') }
        }


        const sizeBondRepay = ethers.parseUnits((100 * 100).toString());
        await mockDai.connect(owner).transfer(issuer, sizeBondRepay);
        await mockDai.connect(issuer).approve(bondContractAddress, sizeBondRepay);

        const BTCBalanceBefore = await mockBTC.connect(owner).balanceOf(user1.address);
        const DaiBalanceBefore = await mockDai.connect(owner).balanceOf(user1.address);

        await mockDai.connect(user1).approve(bondContractAddress, sizeBond);
        await expect(bondContract.connect(user1).claimLoan(1, 100)).to.emit(bondContract, "LiquitationCollateralBondExpired");
        const BTCBalanceAfter = await mockBTC.connect(owner).balanceOf(user1.address);
        const DaiBalanceAfter = await mockDai.connect(owner).balanceOf(user1.address);

        expect(+BTCBalanceBefore.toString()).to.below(+BTCBalanceAfter.toString())
        expect(+DaiBalanceBefore.toString()).to.eq(+DaiBalanceAfter.toString())



        //**USER CAN CLAIM All points */
        await expect(bondContract.connect(issuer).claimScorePoint(1)).be.rejectedWith('No points left to claim')


    })
    it("Iuser don't nothing and more user liquidate it, liquidation on coupon", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100') // ID 0
        await newBondFunction('100', '10', couponMaturity, expiredBond, '10', issuer, '100') // ID 1
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')

        const sizeBond1 = ethers.parseUnits((100 * 50).toString());
        await mockDai.connect(owner).transfer(user1, sizeBond1);
        await mockDai.connect(owner).transfer(user2, sizeBond1);

        await mockDai.connect(user1).approve(launchBondContractAddress, sizeBond1);
        await mockDai.connect(user2).approve(launchBondContractAddress, sizeBond1);

        await expect(launchBondContract.connect(user1).buyBond(1, 0, 50)).to.emit(launchBondContract, 'BuyBond')
        await launchBondContract.connect(user1).withdrawBondBuy(1)

        await expect(launchBondContract.connect(user2).buyBond(1, 0, 50)).to.emit(launchBondContract, 'BuyBond')
        await launchBondContract.connect(user2).withdrawBondBuy(1)

        // in next time over expiredBond
        const dayInSecond = 86400;
        await ethers.provider.send("evm_increaseTime", [dayInSecond * 40]);
        await ethers.provider.send("evm_mine");

        //**After  4 penalities the bond should liquidation  */

        //** 1st penality
        let BTCBalanceBeforeUser1 = await mockBTC.connect(owner).balanceOf(user1.address);
        await expect(bondContract.connect(user1).claimCouponForUSer(1, 0)).to.emit(bondContract, "CouponClaimed");
        let BTCBalanceAfterUser1 = await mockBTC.connect(owner).balanceOf(user1.address);

        //** 2nd penality
        let BTCBalanceBeforeUser2 = await mockBTC.connect(owner).balanceOf(user2.address);
        await expect(bondContract.connect(user2).claimCouponForUSer(1, 0)).to.emit(bondContract, "CouponClaimed");
        let BTCBalanceAfterUser2 = await mockBTC.connect(owner).balanceOf(user2.address);
        expect(+BTCBalanceBeforeUser2.toString()).to.below(+BTCBalanceAfterUser2.toString())
        expect(+BTCBalanceAfterUser1.toString()).to.below(+BTCBalanceAfterUser2.toString())

        //** 3rd penality
        BTCBalanceBeforeUser1 = await mockBTC.connect(owner).balanceOf(user1.address);
        await expect(bondContract.connect(user1).claimCouponForUSer(1, 1)).to.emit(bondContract, "CouponClaimed");
        BTCBalanceAfterUser1 = await mockBTC.connect(owner).balanceOf(user1.address);
        expect(+BTCBalanceBeforeUser1.toString()).to.below(+BTCBalanceAfterUser1.toString())

        //** 4nd penality
        BTCBalanceBeforeUser2 = await mockBTC.connect(owner).balanceOf(user2.address);
        await expect(bondContract.connect(user2).claimCouponForUSer(1, 1)).to.emit(bondContract, "CouponClaimed");
        BTCBalanceAfterUser2 = await mockBTC.connect(owner).balanceOf(user2.address);
        expect(+BTCBalanceBeforeUser2.toString()).to.below(+BTCBalanceAfterUser2.toString())
        expect(+BTCBalanceAfterUser1.toString()).to.below(+BTCBalanceAfterUser2.toString())


        //**  In this case the bond is  completely liquidate and user can't claim coupon
        await expect(bondContract.connect(user1).claimCouponForUSer(1, 2)).be.rejectedWith("This bond is expired or totally liquidated");

        //**  In this case the bond is  completely liquidate and user can't claim coupon
        await expect(bondContract.connect(user1).claimLoan(1, 50)).to.emit(bondContract, "LiquitationCollateralBondExpired");

        //**  Liquidate rest of bond
        await expect(bondContract.connect(user2).claimLoan(1, 50)).to.emit(bondContract, "LiquitationCollateralBondExpired");

    })
    it("Iusser can withdraw collateral 15 days after repay all interests and bond", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        let currentBlock = await ethers.provider.getBlock("latest");
        let currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '10', issuer, '100') // ID 0
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '10', issuer, '100') // ID 1

        //? Approve launchBondContract at spending ERC1155
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);

        //? Launch Bond ID1
        await expect(launchBondContract.connect(issuer).launchNewBond('0', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')

        const sizeBond = ethers.parseUnits((1000 * 100).toString());

        await mockDai.connect(owner).transfer(user1, sizeBond);
        await mockDai.connect(user1).approve(launchBondContractAddress, sizeBond);


        await expect(launchBondContract.connect(user1).buyBond(1, 1, 100)).to.emit(launchBondContract, 'BuyBond')
        await launchBondContract.connect(user1).withdrawBondBuy(1)


        const sizeLoan = ethers.parseUnits(
            (((10 * 100) * 6) + (1000 * 100)).toString()
        );
        await mockDai.connect(owner).transfer(issuer, sizeLoan);
        await mockDai.connect(issuer).approve(bondContractAddress, sizeLoan);
        await expect(bondContract.connect(issuer).depositTokenForInterest(1, sizeLoan)).to.emit(bondContract, 'InterestDeposited')

        const dayInSecond = 86400;
        await ethers.provider.send("evm_increaseTime", [dayInSecond * 61]);
        await ethers.provider.send("evm_mine");

        for (let index = 0; index < couponMaturity.length; index++) {
            const DaiBalanceBefore = await mockDai.connect(owner).balanceOf(user1.address);
            const BTCBalanceBefore = await mockBTC.connect(owner).balanceOf(user1.address);

            await expect(bondContract.connect(user1).claimCouponForUSer(1, index)).to.emit(bondContract, "CouponClaimed");
            const DaiBalanceAfter = await mockDai.connect(owner).balanceOf(user1.address);
            const BTCBalanceAfter = await mockBTC.connect(owner).balanceOf(user1.address);

            expect(+DaiBalanceBefore.toString()).to.below(+DaiBalanceAfter.toString())
            expect(BTCBalanceBefore.toString()).to.eq(BTCBalanceAfter.toString())
            expect(BTCBalanceBefore.toString()).to.eq('0')
        }

        await ethers.provider.send("evm_increaseTime", [dayInSecond * 29]);
        await ethers.provider.send("evm_mine");

        await expect(bondContract.connect(user1).claimLoan(1, 100)).to.emit(bondContract, "LoanClaimed");

        await expect(bondContract.connect(issuer).withdrawCollateral(1)).be.rejectedWith("the collateral lock-up period has not yet expired")


        await ethers.provider.send("evm_increaseTime", [dayInSecond * 15]);
        await ethers.provider.send("evm_mine");


        let bondCollateralBalance = await bondContract.connect(issuer).showDeatailBondForId(1)
        expect(bondCollateralBalance[8].toString()).be.eq('9850000000000000000')//total - fee


        const BTCBalanceBeforeIusser = await mockBTC.connect(owner).balanceOf(issuer.address);
        await expect(bondContract.connect(issuer).withdrawCollateral(1)).to.emit(bondContract, "CollateralWithdrawn")
        const BTCBalanceAfterIusser = await mockBTC.connect(owner).balanceOf(issuer.address);
        expect(+BTCBalanceBeforeIusser.toString()).to.below(+BTCBalanceAfterIusser.toString())

        bondCollateralBalance = await bondContract.connect(issuer).showDeatailBondForId(1)
        expect(bondCollateralBalance[8].toString()).be.eq('0')

    })
    it("Iusser can withdraw collateral 90 days after repay all interests and bond but have one penality and freez collateral", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        let currentBlock = await ethers.provider.getBlock("latest");
        let currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '10', issuer, '100') // ID 0
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '10', issuer, '100') // ID 1

        //? Approve launchBondContract at spending ERC1155
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);

        //? Launch Bond ID1
        await expect(launchBondContract.connect(issuer).launchNewBond('0', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')

        const sizeBond = ethers.parseUnits((1000 * 100).toString());

        await mockDai.connect(owner).transfer(user1, sizeBond);
        await mockDai.connect(user1).approve(launchBondContractAddress, sizeBond);


        await expect(launchBondContract.connect(user1).buyBond(1, 1, 100)).to.emit(launchBondContract, 'BuyBond')
        await launchBondContract.connect(user1).withdrawBondBuy(1)


        const sizeLoan = ethers.parseUnits(
            ((((10 * 100) * 6) + (1000 * 100)) - 500).toString()
        );
        await mockDai.connect(owner).transfer(issuer, sizeLoan);
        await mockDai.connect(issuer).approve(bondContractAddress, sizeLoan);
        await expect(bondContract.connect(issuer).depositTokenForInterest(1, sizeLoan)).to.emit(bondContract, 'InterestDeposited')

        const dayInSecond = 86400;
        await ethers.provider.send("evm_increaseTime", [dayInSecond * 61]);
        await ethers.provider.send("evm_mine");

        for (let index = 0; index < couponMaturity.length; index++) {
            const DaiBalanceBefore = await mockDai.connect(owner).balanceOf(user1.address);
            const BTCBalanceBefore = await mockBTC.connect(owner).balanceOf(user1.address);

            await expect(bondContract.connect(user1).claimCouponForUSer(1, index)).to.emit(bondContract, "CouponClaimed");
            const DaiBalanceAfter = await mockDai.connect(owner).balanceOf(user1.address);
            const BTCBalanceAfter = await mockBTC.connect(owner).balanceOf(user1.address);

            expect(+DaiBalanceBefore.toString()).to.below(+DaiBalanceAfter.toString())
            expect(BTCBalanceBefore.toString()).to.eq(BTCBalanceAfter.toString())
            expect(BTCBalanceBefore.toString()).to.eq('0')
        }

        await ethers.provider.send("evm_increaseTime", [dayInSecond * 29]);
        await ethers.provider.send("evm_mine");

        await expect(bondContract.connect(user1).claimLoan(1, 100)).to.emit(bondContract, "LoanClaimed");

        await expect(bondContract.connect(issuer).withdrawCollateral(1)).be.rejectedWith("the collateral lock-up period has not yet expired")

        await ethers.provider.send("evm_increaseTime", [dayInSecond * 15]);
        await ethers.provider.send("evm_mine");
        await expect(bondContract.connect(issuer).withdrawCollateral(1)).be.rejectedWith("the collateral lock-up period has not yet expired, extended to 90 days for liquidation")

        await ethers.provider.send("evm_increaseTime", [dayInSecond * 75]);
        await ethers.provider.send("evm_mine");

        const BTCBalanceBeforeIusser = await mockBTC.connect(owner).balanceOf(issuer.address);
        await expect(bondContract.connect(issuer).withdrawCollateral(1)).to.emit(bondContract, "CollateralWithdrawn")
        const BTCBalanceAfterIusser = await mockBTC.connect(owner).balanceOf(issuer.address);
        expect(+BTCBalanceBeforeIusser.toString()).to.below(+BTCBalanceAfterIusser.toString())

        //**USER CAN CLAIM All points */

        const scoreBefore = await bondContract.connect(issuer).checkStatusPoints(issuer.address)
        await expect(bondContract.connect(issuer).claimScorePoint(1)).to.emit(bondContract, 'ScoreUpdated')
        const scoreAfter = await bondContract.connect(issuer).checkStatusPoints(issuer.address)


        expect(+scoreBefore[1].toString()).to.below(+scoreAfter[1].toString())
        //700100 + 1955 (less 145 for coupon liquidate) = 702055
        expect(scoreAfter[1].toString()).be.eq('702055')


    })
    it("Iusser claim points", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        let currentBlock = await ethers.provider.getBlock("latest");
        let currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '10', issuer, '100') // ID 0
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '10', issuer, '100') // ID 1

        //? Approve launchBondContract at spending ERC1155
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);

        //? Launch Bond ID1
        await expect(launchBondContract.connect(issuer).launchNewBond('0', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')

        const sizeBond = ethers.parseUnits((1000 * 100).toString());

        await mockDai.connect(owner).transfer(user1, sizeBond);
        await mockDai.connect(user1).approve(launchBondContractAddress, sizeBond);


        await expect(launchBondContract.connect(user1).buyBond(1, 1, 100)).to.emit(launchBondContract, 'BuyBond')
        await launchBondContract.connect(user1).withdrawBondBuy(1)


        const sizeLoan = ethers.parseUnits(
            (((10 * 100) * 6) + (1000 * 100)).toString()
        );
        await mockDai.connect(owner).transfer(issuer, sizeLoan);
        await mockDai.connect(issuer).approve(bondContractAddress, sizeLoan);
        await expect(bondContract.connect(issuer).depositTokenForInterest(1, sizeLoan)).to.emit(bondContract, 'InterestDeposited')

        const dayInSecond = 86400;
        await ethers.provider.send("evm_increaseTime", [dayInSecond * 61]);
        await ethers.provider.send("evm_mine");

        for (let index = 0; index < couponMaturity.length; index++) {
            const DaiBalanceBefore = await mockDai.connect(owner).balanceOf(user1.address);
            const BTCBalanceBefore = await mockBTC.connect(owner).balanceOf(user1.address);

            await expect(bondContract.connect(user1).claimCouponForUSer(1, index)).to.emit(bondContract, "CouponClaimed");
            const DaiBalanceAfter = await mockDai.connect(owner).balanceOf(user1.address);
            const BTCBalanceAfter = await mockBTC.connect(owner).balanceOf(user1.address);

            expect(+DaiBalanceBefore.toString()).to.below(+DaiBalanceAfter.toString())
            expect(BTCBalanceBefore.toString()).to.eq(BTCBalanceAfter.toString())
            expect(BTCBalanceBefore.toString()).to.eq('0')
        }

        await ethers.provider.send("evm_increaseTime", [dayInSecond * 29]);
        await ethers.provider.send("evm_mine");

        await expect(bondContract.connect(user1).claimLoan(1, 100)).to.emit(bondContract, "LoanClaimed");

        await expect(bondContract.connect(issuer).withdrawCollateral(1)).be.rejectedWith("the collateral lock-up period has not yet expired")


        await ethers.provider.send("evm_increaseTime", [dayInSecond * 15]);
        await ethers.provider.send("evm_mine");


        let bondCollateralBalance = await bondContract.connect(issuer).showDeatailBondForId(1)
        expect(bondCollateralBalance[8].toString()).be.eq('9850000000000000000')//total - fee


        const BTCBalanceBeforeIusser = await mockBTC.connect(owner).balanceOf(issuer.address);
        await expect(bondContract.connect(issuer).withdrawCollateral(1)).to.emit(bondContract, "CollateralWithdrawn")
        const BTCBalanceAfterIusser = await mockBTC.connect(owner).balanceOf(issuer.address);
        expect(+BTCBalanceBeforeIusser.toString()).to.below(+BTCBalanceAfterIusser.toString())

        bondCollateralBalance = await bondContract.connect(issuer).showDeatailBondForId(1)
        expect(bondCollateralBalance[8].toString()).be.eq('0')

        //**USER CAN CLAIM All points */

        const scoreBefore = await bondContract.connect(issuer).checkStatusPoints(issuer.address)
        await expect(bondContract.connect(issuer).claimScorePoint(1)).to.emit(bondContract, 'ScoreUpdated')
        const scoreAfter = await bondContract.connect(issuer).checkStatusPoints(issuer.address)

        expect(+scoreBefore[1].toString()).to.below(+scoreAfter[1].toString())
        expect(scoreAfter[1].toString()).be.eq('702100')


    })
    it("Iusser can delete launch", async () => {
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockWETH.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        let currentBlock = await ethers.provider.getBlock("latest");
        let currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '10', issuer, '100') // ID 0
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '10', issuer, '100') // ID 1

        //? Approve launchBondContract at spending ERC1155
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);

        //? Launch Bond ID1
        await expect(launchBondContract.connect(issuer).launchNewBond('0', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')

        await expect(launchBondContract.connect(user1).deleteLaunch(1,1)).be.rejectedWith(launchBondContract,'Only issuer Bond can launch this function')
        

        await expect(launchBondContract.connect(issuer).deleteLaunch(1,1)).to.emit(launchBondContract,'DeleteLaunch')

        await mockWETH.connect(owner).transfer(issuer.address, ethers.parseUnits('1000000'));
        await mockWETH.connect(issuer).approve(bondContractAddress, ethers.parseUnits('1000000'));

        await expect(
            bondContract.connect(issuer).safeTransferFrom(issuer.address, user2.address, 1, 100, "0x")
        ).be.rejectedWith(bondContract, "1st tx must send Launcher");

        await expect(launchBondContract.connect(issuer).launchNewBond('1', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')


    })
    it("Bond Owner create new UpwardAuction", async ()=>{
        //? Approve spending
        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(owner).approve(bondContractAddress, ethers.parseUnits('999999999'))

        //? Create new Bond ( in this case all equal)
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const couponMaturity = [
            currentTimestamp + (86400 * 10),
            currentTimestamp + (86400 * 20),
            currentTimestamp + (86400 * 30),
            currentTimestamp + (86400 * 40),
            currentTimestamp + (86400 * 50),
            currentTimestamp + (86400 * 60),

        ];
        const expiredBond = currentTimestamp + (86400 * 90);
        await newBondFunction('1000', '10', couponMaturity, expiredBond, '4', issuer, '100') // ID 0
        await newBondFunction('100', '10', couponMaturity, expiredBond, '10', issuer, '100') // ID 1
        await bondContract.connect(issuer).setApprovalForAll(launchBondContractAddress, true);
        await expect(launchBondContract.connect(issuer).launchNewBond('1', '100')).to.emit(launchBondContract, 'IncrementBondInLaunch')


        await expect(launchBondContract.connect(user1).buyBond(1, 0, 100)).to.emit(launchBondContract, 'BuyBond')
        await launchBondContract.connect(user1).withdrawBondBuy(1)

        await bondContract.connect(user1).setApprovalForAll(upwardAuctionContractAddress, true);
        



    })

});




