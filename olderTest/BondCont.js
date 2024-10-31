const { expect } = require("chai");
const { ethers } = require("hardhat");

describe('BondContract', () => {
    let bondContract, mockDai, mockBTC;
    let owner, issuer, user1, user2;
    let bondContractAddress

    let newBondCreate, showBondDetail, depositTokenOnContract


    beforeEach(async () => {
        const BondContract = await ethers.getContractFactory('BondContract');
        const MockToken = await ethers.getContractFactory('MockToken');
        mockDai = await MockToken.deploy(1000000000000000, 'Dai Token', 'DAI');
        mockBTC = await MockToken.deploy(1000000000000, 'Bitcoin', 'BTC');
        [owner, issuer, user1, user2] = await ethers.getSigners();
        bondContract = await BondContract.deploy(owner);
        await mockDai.waitForDeployment()
        await mockBTC.waitForDeployment()
        await bondContract.waitForDeployment();
        bondContractAddress = await bondContract.getAddress()


        await mockBTC.connect(owner).approve(await bondContract.getAddress(), 1000000000000)
        await mockDai.connect(owner).approve(await bondContract.getAddress(), 1000000000000000)




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
            await mockBTC.connect(issuer).approve(await bondContract.getAddress(), collateralAmount);

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
        }




    })
    it('Contract deployed with success', async () => {
        expect(await bondContract.getAddress()).to.properAddress
    });
    it('Property of Contract', async () => {
        const ownerContract = await bondContract.owner()
        expect(ownerContract).to.equal(owner.address);
    })
    it('Creazione di un nuovo Bond', async () => {
        await mockBTC.connect(owner).transfer(issuer.address, 5000000)
        await newBondCreate()
        showBondDetail = async (id) => {
            const det = await bondContract.connect(owner).showDeatailBondForId(id)
            return det
        }


        const bondDet = await showBondDetail(0)
        //console.log(bondDet.collateral.toString())

        const balanceContract = await mockBTC.balanceOf(bondContractAddress)
        //console.log(balanceContract.toString())


    })/*
    it('Pagamento di una cedola', async () => {
        await mockBTC.connect(owner).transfer(issuer.address, 5000000)
        await newBondCreate()
        showBondDetail = async (id) => {
            const det = await bondContract.connect(owner).showDeatailBondForId(id)
            return det
        }
        // Trasferisci parte del bond a user1
        await bondContract.connect(issuer).safeTransferFrom(issuer.address, user1.address, 0, 50, "0x");

        // Deposito i token per pagare gli interessi
        await mockDai.connect(owner).transfer(issuer.address, 5000000);
        await mockDai.connect(issuer).approve(await bondContract.getAddress(), 5000000);
        await bondContract.connect(issuer).depositTokenForInterest(0, 5000000);

        const bondBefore = await showBondDetail(0)

        // Simula il passaggio del tempo di 1 giorno
        await ethers.provider.send("evm_increaseTime", [86400]);
        await ethers.provider.send("evm_mine");

        // Coso richiede la cedola
        await expect(bondContract.connect(user1).claimCouponForUSer(0, 0)).to.emit(bondContract, "CouponClaimed");

        const bondfAfter = await showBondDetail(0)
        const balanceDaiUSer1 = await mockDai.connect(user1).balanceOf(user1)
        const balanceDaiContract = await mockDai.connect(owner).balanceOf(bondContractAddress)

        expect(+(bondBefore.balancLoanRepay.toString())).to.equal(+balanceDaiUSer1.toString())
        // Assicurati che sia stato pagato il giusto all utente
        expect(+balanceDaiUSer1.toString()).to.equal(50 * (+(bondfAfter.interest.toString())))
        //Assicurati che il bilancio dei token sia uguale a quello segnalato
        expect(+balanceDaiContract.toString()).to.equal((+(bondfAfter.balancLoanRepay.toString())))


    })*/
    /*
    it('Pagamento di una cedola con liquidazione parziale', async () => {
        await mockBTC.connect(owner).transfer(issuer.address, 5000000)
        await newBondCreate()
        showBondDetail = async (id) => {
            const det = await bondContract.connect(owner).showDeatailBondForId(id)
            return det
        }
        // Trasferisci parte del bond a user1
        await bondContract.connect(issuer).safeTransferFrom(issuer.address, user1.address, 0, 50, "0x");

        // Deposito i token per pagare gli interessi
        const nuymero = 4000000

        await mockDai.connect(owner).transfer(issuer.address, nuymero);
        await mockDai.connect(issuer).approve(await bondContract.getAddress(), nuymero);
        await bondContract.connect(issuer).depositTokenForInterest(0, nuymero);

        const bondBefore = await showBondDetail(0)
        const balanceBTCContractBefore = await mockBTC.connect(owner).balanceOf(bondContractAddress)


        // Simula il passaggio del tempo di 1 giorno
        await ethers.provider.send("evm_increaseTime", [86400]);
        await ethers.provider.send("evm_mine");

        // Coso richiede la cedola
        await expect(bondContract.connect(user1).claimCouponForUSer(0, 0)).to.emit(bondContract, "CouponClaimed");

        const bondAfter = await showBondDetail(0)
        const balanceBTCContractAfter = await mockBTC.connect(owner).balanceOf(bondContractAddress)

        expect(bondBefore.collateral.toString()).to.equal("5000000");
        expect(bondAfter.collateral.toString()).to.equal("4995000");

        const collateralReduction = (+bondBefore.collateral.toString()) - (+bondAfter.collateral.toString());
        expect(collateralReduction.toString()).to.equal("5000");

        expect(balanceBTCContractBefore.toString()).to.equal("5000000");
        expect(balanceBTCContractAfter.toString()).to.equal("4995000");

        const btcReduction = (+balanceBTCContractBefore.toString())-(+balanceBTCContractAfter);
        expect(btcReduction.toString()).to.equal("5000");

        const liquidatedAmountPerBond = 5000 / 10;
        expect(liquidatedAmountPerBond.toString()).to.equal("500");


    })
    */


    /*
    it('Seconda e terza Liquidazione di cedola', async () => {
        await mockBTC.connect(owner).transfer(issuer.address, 5000000)
        await newBondCreate()
        showBondDetail = async (id) => {
            const det = await bondContract.connect(owner).showDeatailBondForId(id)
            return det
        }
        // Trasferisci parte del bond a user1
        await bondContract.connect(issuer).safeTransferFrom(issuer.address, user1.address, 0, 50, "0x");

        // Deposito i token per pagare gli interessi
        const nuymero = 4000000

        await mockDai.connect(owner).transfer(issuer.address, nuymero);
        await mockDai.connect(issuer).approve(await bondContract.getAddress(), nuymero);
        await bondContract.connect(issuer).depositTokenForInterest(0, nuymero);

        const bondBefore = await showBondDetail(0)
        const balanceBTCContractBefore = await mockBTC.connect(owner).balanceOf(bondContractAddress)


        // Simula il passaggio del tempo di 1 giorno
        await ethers.provider.send("evm_increaseTime", [86400]);
        await ethers.provider.send("evm_mine");

        // Coso richiede la cedola
        await expect(bondContract.connect(user1).claimCouponForUSer(0, 0)).to.emit(bondContract, "CouponClaimed");

        const bondAfter = await showBondDetail(0)
        const balanceBTCContractAfter = await mockBTC.connect(owner).balanceOf(bondContractAddress)

        expect(bondBefore.collateral.toString()).to.equal("5000000");
        expect(bondAfter.collateral.toString()).to.equal("4995000");

        const collateralReduction = (+bondBefore.collateral.toString()) - (+bondAfter.collateral.toString());
        expect(collateralReduction.toString()).to.equal("5000");

        expect(balanceBTCContractBefore.toString()).to.equal("5000000");
        expect(balanceBTCContractAfter.toString()).to.equal("4995000");

        const btcReduction = (+balanceBTCContractBefore.toString()) - (+balanceBTCContractAfter.toString());
        expect(btcReduction.toString()).to.equal("5000");

        const liquidatedAmountPerBond = 5000 / 10;
        expect(liquidatedAmountPerBond.toString()).to.equal("500");


        // Deposito i token per pagare gli interessi
        const nuumero2 = 4000000

        await mockDai.connect(owner).transfer(issuer.address, nuumero2);
        await mockDai.connect(issuer).approve(await bondContract.getAddress(), nuumero2);
        await bondContract.connect(issuer).depositTokenForInterest(0, nuumero2);



        // Simula il passaggio del tempo di 1 giorno

        await ethers.provider.send("evm_increaseTime", [172800]);
        await ethers.provider.send("evm_mine");




        console.log(bondAfter.collateral.toString())

        await expect(bondContract.connect(user1).claimCouponForUSer(0, 1)).to.emit(bondContract, "CouponClaimed");

        const bondAfterSecondLiquidation = await showBondDetail(0)


        console.log(bondAfterSecondLiquidation.collateral.toString())



        // Deposito i token per pagare gli interessi
        const nuumero3 = 4000000

        await mockDai.connect(owner).transfer(issuer.address, nuumero3);
        await mockDai.connect(issuer).approve(await bondContract.getAddress(), nuumero3);
        await bondContract.connect(issuer).depositTokenForInterest(0, nuumero3);

        // Simula il passaggio del tempo di 1 giorno

        await ethers.provider.send("evm_increaseTime", [259200]);
        await ethers.provider.send("evm_mine");




        await expect(bondContract.connect(user1).claimCouponForUSer(0, 2)).to.emit(bondContract, "CouponClaimed");

        const bondAfterThirdLiquidation = await showBondDetail(0)


        console.log(bondAfterThirdLiquidation.collateral.toString())

    })
    */


    /*
    it('Liquidazione totale per 3 cedola non pagata', async () => {
        await mockBTC.connect(owner).transfer(issuer.address, 5000000)
        await newBondCreate()
        showBondDetail = async (id) => {
            const det = await bondContract.connect(owner).showDeatailBondForId(id)
            return det
        }
        // Trasferisci parte del bond a user1
        await bondContract.connect(issuer).safeTransferFrom(issuer.address, user1.address, 0, 50, "0x");

        // Deposito i token per pagare gli interessi
        const nuymero = 4000000

        await mockDai.connect(owner).transfer(issuer.address, nuymero);
        await mockDai.connect(issuer).approve(await bondContract.getAddress(), nuymero);
        await bondContract.connect(issuer).depositTokenForInterest(0, nuymero);

        const bondBefore = await showBondDetail(0)
        const balanceBTCContractBefore = await mockBTC.connect(owner).balanceOf(bondContractAddress)


        // Simula il passaggio del tempo di 1 giorno
        await ethers.provider.send("evm_increaseTime", [86400]);
        await ethers.provider.send("evm_mine");

        // Coso richiede la cedola
        await expect(bondContract.connect(user1).claimCouponForUSer(0, 0)).to.emit(bondContract, "CouponClaimed");

        const bondAfter = await showBondDetail(0)
        const balanceBTCContractAfter = await mockBTC.connect(owner).balanceOf(bondContractAddress)

        expect(bondBefore.collateral.toString()).to.equal("5000000");
        expect(bondAfter.collateral.toString()).to.equal("4995000");

        const collateralReduction = (+bondBefore.collateral.toString()) - (+bondAfter.collateral.toString());
        expect(collateralReduction.toString()).to.equal("5000");

        expect(balanceBTCContractBefore.toString()).to.equal("5000000");
        expect(balanceBTCContractAfter.toString()).to.equal("4995000");

        const btcReduction = (+balanceBTCContractBefore.toString()) - (+balanceBTCContractAfter.toString());
        expect(btcReduction.toString()).to.equal("5000");

        const liquidatedAmountPerBond = 5000 / 10;
        expect(liquidatedAmountPerBond.toString()).to.equal("500");


        // Deposito i token per pagare gli interessi
        const nuumero2 = 4000000

        await mockDai.connect(owner).transfer(issuer.address, nuumero2);
        await mockDai.connect(issuer).approve(await bondContract.getAddress(), nuumero2);
        await bondContract.connect(issuer).depositTokenForInterest(0, nuumero2);



        // Simula il passaggio del tempo di 1 giorno

        await ethers.provider.send("evm_increaseTime", [172800]);
        await ethers.provider.send("evm_mine");




        console.log(bondAfter.collateral.toString())

        await expect(bondContract.connect(user1).claimCouponForUSer(0, 1)).to.emit(bondContract, "CouponClaimed");

        const bondAfterSecondLiquidation = await showBondDetail(0)


        console.log(bondAfterSecondLiquidation.collateral.toString())



        // Deposito i token per pagare gli interessi
        const nuumero3 = 4000000

        await mockDai.connect(owner).transfer(issuer.address, nuumero3);
        await mockDai.connect(issuer).approve(await bondContract.getAddress(), nuumero3);
        await bondContract.connect(issuer).depositTokenForInterest(0, nuumero3);

        // Simula il passaggio del tempo di 1 giorno

        await ethers.provider.send("evm_increaseTime", [259200]);
        await ethers.provider.send("evm_mine");




        await expect(bondContract.connect(user1).claimCouponForUSer(0, 2)).to.emit(bondContract, "CouponClaimed");

        const bondAfterThirdLiquidation = await showBondDetail(0)


        console.log(bondAfterThirdLiquidation.collateral.toString())


            // Deposito i token per pagare gli interessi
            const nuumero4 = 4000000

            await mockDai.connect(owner).transfer(issuer.address, nuumero4);
            await mockDai.connect(issuer).approve(await bondContract.getAddress(), nuumero4);
            await bondContract.connect(issuer).depositTokenForInterest(0, nuumero4);
    
            // Simula il passaggio del tempo di 1 giorno
    
            await ethers.provider.send("evm_increaseTime", [345600]);
            await ethers.provider.send("evm_mine");
    
    
    
    
            await expect(bondContract.connect(user1).claimCouponForUSer(0, 3)).to.emit(bondContract, "CouponClaimed");
    
            const bondAfterFourLiquidation = await showBondDetail(0)
    
    
            console.log(bondAfterFourLiquidation.collateral.toString())


        

    })
    */


    it('Liquidazione finale in caso di insolvenza alla fine ', async () => {
        await mockBTC.connect(owner).transfer(issuer.address, 5000000)
        await newBondCreate()
        showBondDetail = async (id) => {
            const det = await bondContract.connect(owner).showDeatailBondForId(id)
            return det
        }
        // Trasferisci parte del bond a user1
        await bondContract.connect(issuer).safeTransferFrom(issuer.address, user1.address, 0, 100, "0x");

        // Deposito i token per pagare gli interessi
        const nuymero = 5000000000

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
        await expect(bondContract.connect(user1).claimCouponForUSer(0,1)).to.emit(bondContract, "CouponClaimed");

        await ethers.provider.send("evm_increaseTime", [259200]);
        await ethers.provider.send("evm_mine");
        await expect(bondContract.connect(user1).claimCouponForUSer(0, 2)).to.emit(bondContract, "CouponClaimed");

        await ethers.provider.send("evm_increaseTime", [345600]);
        await ethers.provider.send("evm_mine");
        await expect(bondContract.connect(user1).claimCouponForUSer(0, 3)).to.emit(bondContract, "CouponClaimed");


        await ethers.provider.send("evm_increaseTime", [432000]);
        await ethers.provider.send("evm_mine")


        const numeroFinale = 100000000
        await mockDai.connect(owner).transfer(issuer.address, numeroFinale);
        await mockDai.connect(issuer).approve(await bondContract.getAddress(), numeroFinale);
        await bondContract.connect(issuer).depositTokenForInterest(0, numeroFinale);

        const bondBefore = await showBondDetail(0)
        const balanceBTCContractBefore = await mockBTC.connect(owner).balanceOf(bondContractAddress)

        //console.log(bondBefore.collateral.toString())
        //console.log(balanceBTCContractBefore.toString())



        await expect(bondContract.connect(user1).claimLoan(0,100)).to.emit(bondContract,"LoanClaimed");

        const bondAfter = await showBondDetail(0)
        const balanceBTCContractAfter = await mockBTC.connect(owner).balanceOf(bondContractAddress)

        //console.log(bondAfter.collateral.toString())
        //console.log(balanceBTCContractAfter.toString())

        
    })


    /**
     * test fatti fin qui
     * 
     * 
     * 1. nuova cedola
     * 2. deposito da parte del'emittente
     * 3. riscossione di una cedola
     * 4. liquidazione di una o più scadenze (qui da capire se la logica delle 3 scadenze sempre e comunque mi va bene)
     * 5. pagamento del debito alla fine
     * 6. liquidazione finale della cedola
     * 7. riscossione da parte dell'emittente del collaterale alla scadenza se tutto va bene V
     * 8. riscossione da parte dell'emittente del collaterale alla scadenza se tutto va male V
     * 9. assegnazione punti V
     * 10. aggiornamento punti alla fine se tutto va bene 
     * 11. aggiornamento punti in caso di penalità
     * 12. perdita di punti se tutto va male
     * test da fare
     * 
     *
     * 
     * 7. fee sul nuovo bond
     * 8. fee sul pagamento della cedola
     * 9. fee sulla liquidazione
     * 10. fee affa fine
     * 11. prelievo fees 
     * 
     */




})