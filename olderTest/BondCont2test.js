const { expect } = require("chai");
const { ethers } = require("hardhat");

describe('BondContract', () => {
    let bondContract, mockDai, mockBTC;
    let owner, issuer, user1, user2;
    let bondContractAddress;

    let newBondCreate, showBondDetail, depositTokenOnContract;

    beforeEach(async () => {
        const BondContract = await ethers.getContractFactory('BondContract');
        const MockToken = await ethers.getContractFactory('MockToken');
        mockDai = await MockToken.deploy("1000000000000000000000", 'Dai Token', 'DAI');
        mockBTC = await MockToken.deploy("10000000000000000000", 'Bitcoin', 'BTC');
        [owner, issuer, user1, user2] = await ethers.getSigners();
        bondContract = await BondContract.deploy(owner);
        await mockDai.waitForDeployment();
        await mockBTC.waitForDeployment();
        await bondContract.waitForDeployment();
        bondContractAddress = await bondContract.getAddress();

        await mockBTC.connect(owner).approve(bondContractAddress, 1000000000000);
        await mockDai.connect(owner).approve(bondContractAddress, 1000000000000000);

        newBondCreate = async () => {
            const sizeLoan = 10000000;
            const interest = 100000;
            const couponMaturity = [
                Math.floor(Date.now() / 1000) + 86400,    // Prima scadenza: 1 giorno
                Math.floor(Date.now() / 1000) + 172800,   // Seconda scadenza: 2 giorni
                Math.floor(Date.now() / 1000) + 259200,   // Terza scadenza: 3 giorni
                Math.floor(Date.now() / 1000) + 345600    // Quarta scadenza: 4 giorni
            ];
            const expiredBond = Math.floor(Date.now() / 1000) + 432000;
            const collateralAmount = 5000000;
            const bondAmount = 100;
            const description = "Test bond";

            // Autorizza il contratto a usare BTC come collateral
            await mockBTC.connect(issuer).approve(bondContractAddress, collateralAmount);

            // Crea un nuovo bond
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

            // Verifica che il bond sia stato creato correttamente
            const bondDetails = await bondContract.showDeatailBondForId(0);
            expect(bondDetails.issuer).to.equal(issuer.address);
            expect(bondDetails.sizeLoan).to.equal(sizeLoan);
            expect(bondDetails.collateral).to.equal(collateralAmount);
        };
    });

    it('Riscossione da parte dell\'emittente del collaterale alla scadenza', async () => {
        await mockBTC.connect(owner).transfer(issuer.address, 5000000);
        await newBondCreate();

        showBondDetail = async (id) => {
            const det = await bondContract.connect(owner).showDeatailBondForId(id);
            return det;
        };

        // Trasferisci parte del bond a user1
        await bondContract.connect(issuer).safeTransferFrom(issuer.address, user1.address, 0, 50, "0x");

        // Deposito i token per pagare gli interessi
        const depositAmount = 5000000000;
        await mockDai.connect(owner).transfer(issuer.address, depositAmount);
        await mockDai.connect(issuer).approve(bondContractAddress, depositAmount);
        await bondContract.connect(issuer).depositTokenForInterest(0, depositAmount);

        // Simula il passaggio del tempo fino alla scadenza
        await ethers.provider.send("evm_increaseTime", [345600]);
        await ethers.provider.send("evm_mine");

        // Verifica lo stato del bond prima della riscossione del collaterale
        const bondBefore = await showBondDetail(0);
        expect(bondBefore.collateral.toString()).to.equal("5000000");


        // Simula il passaggio del tempo fino alla scadenza
        await ethers.provider.send("evm_increaseTime", [1729546568]);
        await ethers.provider.send("evm_mine");

        // Esegui la richiesta di prelievo del collaterale
        await expect(bondContract.connect(issuer).withdrawCollateral(0)).to.emit(bondContract, "CollateralWithdrawn");

        //Verifica che il collaterale sia stato correttamente prelevato
        const bondAfter = await showBondDetail(0);
        expect(bondAfter.collateral.toString()).to.equal("0");
        //
        const balanceBTCIssuer = await mockBTC.connect(owner).balanceOf(issuer.address);
        expect(balanceBTCIssuer.toString()).to.equal("5000000"); // L'intero collaterale è stato trasferito all'emittente
    });


    it('Simula liquidazione di 10 cedole insolventi su 100 e verifica recupero collaterale dopo 90 giorni', async () => {
        await mockBTC.connect(owner).transfer(issuer.address, 5000000)
        await newBondCreate()
        showBondDetail = async (id) => {
            const det = await bondContract.connect(owner).showDeatailBondForId(id)
            return det
        }
        // Trasferisci parte del bond a user1
        await bondContract.connect(issuer).safeTransferFrom(issuer.address, user1.address, 0, 100, "0x");

        // Deposito i token per pagare gli interessi
        //const nuymero = 1040000000 //somma esatta per pagare tutto 
        const nuymero = 940000000  // qui mancano 10 cedole da pagare alla fine

        await mockDai.connect(owner).transfer(issuer.address, nuymero);
        await mockDai.connect(issuer).approve(await bondContract.getAddress(), nuymero);
        await bondContract.connect(issuer).depositTokenForInterest(0, nuymero);


        // Simula il passaggio del tempo di 1 giorno
        await ethers.provider.send("evm_increaseTime", [86400]);
        await ethers.provider.send("evm_mine");

        // Coso richiede la cedola
        await expect(bondContract.connect(user1).claimCouponForUSer(0, 0)).to.emit(bondContract, "CouponClaimed");

        await ethers.provider.send("evm_increaseTime", [172800]);
        await ethers.provider.send("evm_mine");
        await expect(bondContract.connect(user1).claimCouponForUSer(0, 1)).to.emit(bondContract, "CouponClaimed");

        await ethers.provider.send("evm_increaseTime", [259200]);
        await ethers.provider.send("evm_mine");
        await expect(bondContract.connect(user1).claimCouponForUSer(0, 2)).to.emit(bondContract, "CouponClaimed");

        await ethers.provider.send("evm_increaseTime", [345600]);
        await ethers.provider.send("evm_mine");
        await expect(bondContract.connect(user1).claimCouponForUSer(0, 3)).to.emit(bondContract, "CouponClaimed");


        await ethers.provider.send("evm_increaseTime", [432000]);
        await ethers.provider.send("evm_mine")



        await expect(bondContract.connect(user1).claimLoan(0, 100)).to.emit(bondContract, "LoanClaimed");


        // Simula il passaggio di 90 giorni (7,776,000 secondi) dalla scadenza attuale
        await ethers.provider.send("evm_increaseTime", [8208000]);  // 90 giorni più 5 giorni già aggiunti
        await ethers.provider.send("evm_mine");


        await expect(bondContract.connect(issuer).withdrawCollateral(0)).to.emit(bondContract, "CollateralWithdrawn");


        const bondAfter = await showBondDetail(0)
        const balanceBtcIusser = await mockBTC.connect(issuer).balanceOf(issuer.address);
        expect(bondAfter.collateral.toString()).to.eq("0")

        expect(balanceBtcIusser.toString()).to.eq("4700000")
        //console.log(balanceBtcIusser.toString())




    });



});









/**
 *  function claimScorePoint(
        uint _id
    )


    function checkStatusPoints(
        address _iusser
 */