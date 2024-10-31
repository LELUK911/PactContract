const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BondContract", function () {
    let bondContract, mockDai, mockBTC;
    let owner, issuer, user1, user2;

    beforeEach(async () => {
        const BondContract = await ethers.getContractFactory("BondContract");
        const MockToken = await ethers.getContractFactory("MockToken");

        mockDai = await MockToken.deploy(1000000000, "Dai Token", "DAI");
        mockBTC = await MockToken.deploy(1000000, "Bitcoin", "BTC");
        [owner, issuer, user1, user2] = await ethers.getSigners();
        
        bondContract = await BondContract.deploy(owner.address);

        await mockDai.waitForDeployment();
        await mockBTC.waitForDeployment();
        await bondContract.waitForDeployment();


        // Approve bondContract to spend tokens on behalf of the owner
        await mockBTC.connect(owner).approve(bondContract.address, 1000000);
        await mockDai.connect(owner).approve(bondContract.address, 1000000000);
    });

    it("Dovrebbe creare un nuovo bond", async function () {
        const sizeLoan = 1000;
        const interest = 10;
        const couponMaturity = [Math.floor(Date.now() / 1000) + 86400, Math.floor(Date.now() / 1000) + 172800];
        const expiredBond = Math.floor(Date.now() / 1000) + 259200;
        const collateralAmount = 500;
        const bondAmount = 100;
        const description = "Test bond";

        // Autorizza il contratto a usare BTC come collateral
        await mockBTC.connect(issuer).approve(bondContract.address, collateralAmount);

        // Crea un nuovo bond
        await expect(
            bondContract.connect(issuer).createNewBond(
                issuer.address,
                mockDai.address,
                sizeLoan,
                interest,
                couponMaturity,
                expiredBond,
                mockBTC.address,
                collateralAmount,
                bondAmount,
                description
            )
        ).to.emit(bondContract, "BondCreated");

        // Verifica che il bond sia stato creato correttamente
        const bondDetails = await bondContract.showDeatailBondForId(0);
        expect(bondDetails.issuer).to.equal(issuer.address);
        expect(bondDetails.sizeLoan).to.equal(sizeLoan);
        expect(bondDetails.collateral).to.equal(collateralAmount);
    });

    it("Dovrebbe trasferire un bond", async function () {
        const sizeLoan = 1000;
        const interest = 10;
        const couponMaturity = [Math.floor(Date.now() / 1000) + 86400, Math.floor(Date.now() / 1000) + 172800];
        const expiredBond = Math.floor(Date.now() / 1000) + 259200;
        const collateralAmount = 500;
        const bondAmount = 100;
        const description = "Test bond";

        await mockBTC.connect(issuer).approve(bondContract.address, collateralAmount);
        await bondContract.connect(issuer).createNewBond(
            issuer.address,
            mockDai.address,
            sizeLoan,
            interest,
            couponMaturity,
            expiredBond,
            mockBTC.address,
            collateralAmount,
            bondAmount,
            description
        );

        // Trasferisce il bond da issuer a user1
        await expect(
            bondContract.connect(issuer).safeTransferFrom(issuer.address, user1.address, 0, 50, "0x")
        ).to.emit(bondContract, "SafeTransferFrom");

        const user1Balance = await bondContract.balanceOf(user1.address, 0);
        expect(user1Balance).to.equal(50);
    });

    it("Dovrebbe permettere a user1 di richiedere il pagamento della cedola", async function () {
        const sizeLoan = 1000;
        const interest = 10;
        const couponMaturity = [Math.floor(Date.now() / 1000) + 86400]; // Cedola tra 1 giorno
        const expiredBond = Math.floor(Date.now() / 1000) + 259200;
        const collateralAmount = 500;
        const bondAmount = 100;
        const description = "Test bond";

        await mockBTC.connect(issuer).approve(bondContract.address, collateralAmount);
        await bondContract.connect(issuer).createNewBond(
            issuer.address,
            mockDai.address,
            sizeLoan,
            interest,
            couponMaturity,
            expiredBond,
            mockBTC.address,
            collateralAmount,
            bondAmount,
            description
        );

        // Deposito del capitale per pagare la cedola
        await mockDai.connect(issuer).approve(bondContract.address, 200);
        await bondContract.connect(issuer).depositTokenForInterest(0, 200);

        // Trasferisci parte del bond a user1
        await bondContract.connect(issuer).safeTransferFrom(issuer.address, user1.address, 0, 50, "0x");

        // Simula il passaggio del tempo di 1 giorno
        await ethers.provider.send("evm_increaseTime", [86400]);
        await ethers.provider.send("evm_mine");

        // User1 richiede la cedola
        await expect(bondContract.connect(user1).claimCouponForUSer(0, 0)).to.emit(bondContract, "CouponClaimed");

        const remainingBalance = await bondContract.totalSupply(0);
        expect(remainingBalance).to.equal(50); // Cedola riscossa
    });

    it("Dovrebbe permettere all'emittente di ritirare il collaterale dopo la scadenza", async function () {
        const sizeLoan = 1000;
        const interest = 10;
        const couponMaturity = [Math.floor(Date.now() / 1000) + 86400, Math.floor(Date.now() / 1000) + 172800];
        const expiredBond = Math.floor(Date.now() / 1000) + 259200;
        const collateralAmount = 500;
        const bondAmount = 100;
        const description = "Test bond";

        await mockBTC.connect(issuer).approve(bondContract.address, collateralAmount);
        await bondContract.connect(issuer).createNewBond(
            issuer.address,
            mockDai.address,
            sizeLoan,
            interest,
            couponMaturity,
            expiredBond,
            mockBTC.address,
            collateralAmount,
            bondAmount,
            description
        );

        // Simula il passaggio del tempo per la scadenza del bond
        await ethers.provider.send("evm_increaseTime", [259200]); // Passano 3 giorni
        await ethers.provider.send("evm_mine");

        // Ritira il collaterale
        await expect(bondContract.connect(issuer).withdrawCollateral(0)).to.emit(bondContract, "CollateralWithdrawn");

        // Verifica che il collaterale sia stato ritirato
        const bondDetails = await bondContract.showDeatailBondForId(0);
        expect(bondDetails.collateral).to.equal(0);
    });

      it("Dovrebbe permettere a user1 di richiedere il pagamento della cedola", async function () {
        const sizeLoan = 1000;
        const interest = 10;
        const couponMaturity = [Math.floor(Date.now() / 1000) + 86400]; // Cedola tra 1 giorno
        const expiredBond = Math.floor(Date.now() / 1000) + 259200;
        const collateralAmount = 500;
        const bondAmount = 100;
        const description = "Test bond";

        await mockBTC.connect(issuer).approve(bondContract.address, collateralAmount);
        await bondContract.connect(issuer).createNewBond(
            issuer.address,
            mockDai.address,
            sizeLoan,
            interest,
            couponMaturity,
            expiredBond,
            mockBTC.address,
            collateralAmount,
            bondAmount,
            description
        );

        // Deposito del capitale per pagare la cedola
        await mockDai.connect(issuer).approve(bondContract.address, 200);
        await bondContract.connect(issuer).depositTokenForInterest(0, 200);

        // Trasferisci parte del bond a user1
        await bondContract.connect(issuer).safeTransferFrom(issuer.address, user1.address, 0, 50, "0x");

        // Simula il passaggio del tempo di 1 giorno
        await ethers.provider.send("evm_increaseTime", [86400]);
        await ethers.provider.send("evm_mine");

        // User1 richiede la cedola
        await expect(bondContract.connect(user1).claimCouponForUSer(0, 0)).to.emit(bondContract, "CouponClaimed");

        const remainingBalance = await bondContract.totalSupply(0);
        expect(remainingBalance).to.equal(50); // Cedola riscossa
    });
});
