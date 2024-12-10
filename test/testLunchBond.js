const { expect, use } = require("chai");
const { ethers } = require("hardhat");


describe("Test di lancio", () => {
    let bondContract, mockDai, mockBTC, owner, iusser, user1, user2;
    let bondContractAddress, contractLunch, contractLunchAddress;

    let newBondFunction

    beforeEach(async () => {
        [owner, iusser, user1, user2] = await ethers.getSigners()

        const BondContract = await ethers.getContractFactory("BondContract")
        bondContract = await BondContract.deploy(owner)
        await bondContract.waitForDeployment()
        bondContractAddress = await bondContract.getAddress()


        const BondLunch = await ethers.getContractFactory('BondLunch');
        contractLunch = await BondLunch.deploy(bondContractAddress)
        contractLunchAddress = await contractLunch.getAddress()
        const MockToken = await ethers.getContractFactory('MockToken');
        mockDai = await MockToken.deploy(ethers.parseUnits('9000000000000'), 'Dai Token', 'DAI');
        mockBTC = await MockToken.deploy(ethers.parseUnits('9000000000000'), 'Bitcoin', 'BTC');

        await mockDai.waitForDeployment()
        await mockBTC.waitForDeployment()
        await bondContract.waitForDeployment()


        await mockBTC.connect(owner).transfer(iusser.address, ethers.parseUnits('1000000000000'))
        await mockDai.connect(owner).transfer(iusser.address, ethers.parseUnits('1000000000000'))


        newBondFunction = async () => {
            const sizeLoan = ethers.parseUnits('1000');
            const interest = ethers.parseUnits('10');
            const couponMaturity = [
                Math.floor(Date.now() / 1000) + 86400,    // Prima scadenza: 1 giorno
                Math.floor(Date.now() / 1000) + 172800,   // Seconda scadenza: 2 giorni
                Math.floor(Date.now() / 1000) + 259200,   // Terza scadenza: 3 giorni
                Math.floor(Date.now() / 1000) + 345600    // Quarta scadenza: 4 giorni
            ];
            const expiredBond = Math.floor(Date.now() / 1000) + 432000;
            const collateralAmount = ethers.parseUnits('8000');
            const bondAmount = 100;
            const description = "Test bond";
            await mockBTC.connect(iusser).approve(bondContractAddress, ethers.parseUnits('1000000000'))

            await expect(
                bondContract.connect(iusser).createNewBond(
                    iusser.address,
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
    });
    it("Lunch new amazing bond", async () => {

        await newBondFunction()
        await newBondFunction()

        await bondContract.connect(iusser).setApprovalForAll(contractLunchAddress, true);

        await expect(contractLunch.connect(iusser).lunchNewBond('1', '100')).to.emit(contractLunch, 'IncrementBondInLunc')

        // verifiche
        const bondList = await contractLunch.connect(iusser).showBondLunchList()
        expect(bondList[0].toString()).eq("1");

        expect(await contractLunch.connect(owner).showAmountInSellForBond('1')).eq('100');
    })
    it("User can buy some bond? PLS!!!!!", async () => {
        // operazioni preliminari
        await newBondFunction()
        await newBondFunction()
        await bondContract.connect(iusser).setApprovalForAll(contractLunchAddress, true);
        await expect(contractLunch.connect(iusser).lunchNewBond('1', '100')).to.emit(contractLunch, 'IncrementBondInLunc')
        // test
        const sizeBond = ethers.parseUnits('10000');
        await mockDai.connect(owner).transfer(user1, sizeBond);
        await mockDai.connect(user1).approve(contractLunchAddress, sizeBond);
        await expect(contractLunch.connect(user1).buyBond(1, 0, 10)).to.emit(contractLunch, 'BuyBond')
        expect((await contractLunch.connect(user1).showBondForWithdraw(user1,1)).toString()).eq('10')
        await contractLunch.connect(user1).withdrawBondBuy(1)
        // verifiche
        expect(await contractLunch.connect(iusser).balanceIssuer(iusser,mockDai)).eq(sizeBond)
        const balanceBond = await bondContract.connect(user1).balanceOf(user1, 1);
        expect(balanceBond.toString()).eq('10');
        expect(await contractLunch.connect(owner).showAmountInSellForBond('1')).eq('90');
        expect(await mockDai.connect(owner).balanceOf(contractLunchAddress)).eq(sizeBond);
        // operazione post verifiche
        await expect(contractLunch.connect(iusser).withdrawToken(await mockDai.getAddress())).to.emit(contractLunch, 'WitrawToken');
        const contractERC20balance = await mockDai.connect(owner).balanceOf(contractLunchAddress)
        expect(contractERC20balance.toString()).eq('0');
    })
    it("Can increas bond in lunch ? ", async () => {
        await newBondFunction()
        await newBondFunction()
        await bondContract.connect(iusser).setApprovalForAll(contractLunchAddress, true);
        await expect(contractLunch.connect(iusser).lunchNewBond('1', '90')).to.emit(contractLunch, 'IncrementBondInLunc')
        expect(await contractLunch.connect(owner).showAmountInSellForBond('1')).eq('90');
        let bondList = await contractLunch.connect(iusser).showBondLunchList()
        expect(bondList[0].toString()).eq("1");
        let balanceBond = await bondContract.connect(iusser).balanceOf(contractLunchAddress, 1);
        expect(balanceBond.toString()).eq('90');

        await contractLunch.connect(iusser).lunchNewBond('1', '5')
        expect(await contractLunch.connect(owner).showAmountInSellForBond('1')).eq('95');
        bondList = await contractLunch.connect(iusser).showBondLunchList()
        expect(bondList[0].toString()).eq("1");
        balanceBond = await bondContract.connect(iusser).balanceOf(contractLunchAddress, 1);
        expect(balanceBond.toString()).eq('95');
    })
    it("Only iusser can lunch bond + some errore", async () => {
        await newBondFunction()
        await newBondFunction()
        await bondContract.connect(iusser).safeTransferFrom(iusser, user1, 1, 50, "0x")
        await bondContract.connect(user1).setApprovalForAll(contractLunchAddress, true);
        await expect(contractLunch.connect(user1).lunchNewBond('1', '50')).to.be.rejectedWith("Only iusser Bond can lunch thi function")
        await bondContract.connect(iusser).setApprovalForAll(contractLunchAddress, true);
        await expect(contractLunch.connect(iusser).lunchNewBond('1', '0')).to.be.rejectedWith("Set correct amount")
        await expect(contractLunch.connect(iusser).lunchNewBond('1', '110')).to.be.rejectedWith("Set correct amount")

    })
    it("Only User can delete Lunch", async () => {
        await newBondFunction()
        await newBondFunction()
        await newBondFunction()

        await bondContract.connect(iusser).setApprovalForAll(contractLunchAddress, true);
        await bondContract.connect(iusser).setApprovalForAll(contractLunchAddress, true); 
        await expect(contractLunch.connect(iusser).lunchNewBond('1', '100')).to.emit(contractLunch, 'IncrementBondInLunc')
        await expect(contractLunch.connect(iusser).lunchNewBond('2', '100')).to.emit(contractLunch, 'IncrementBondInLunc')
        expect ((await contractLunch.connect(iusser).findIndexBond(2)).toString()).eq('1')
        expect ((await contractLunch.connect(iusser).findIndexBond(1)).toString()).eq('0')

        await expect(contractLunch.connect(iusser).deleteLunch(1, 0)).to.emit(contractLunch, 'DeleteLunch')
        await expect(contractLunch.connect(owner).deleteLunch(2, 1)).to.be.rejectedWith("Only iusser Bond can lunch this function")
        expect( (await bondContract.connect(iusser).balanceOf(iusser,1)).toString()).eq('100') 
    })
})