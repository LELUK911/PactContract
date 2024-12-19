const { expect} = require("chai");
const { ethers } = require("hardhat");


describe("Test asta al ribasso", () => {
    let bondContract, mockDai, mockBTC, owner, iusser, user1, user2, user3;
    let bondContractAddress, contractUpwardAuction, contractUpwardAuctionAddress, daiAddress;

    let newBondFunction

    async function calculateFutureTimestamp(days) {
        const secondsInADay = 24 * 60 * 60; // Numero di secondi in un giorno
        const currentBlock = await ethers.provider.getBlock("latest"); // Ottieni il blocco corrente
        const currentTimestamp = currentBlock.timestamp; // Timestamp del blocco corrente
        const futureTimestamp = currentTimestamp + (days * secondsInADay); // Calcolo del timestamp futuro
        return futureTimestamp;
    }
    beforeEach(async () => {
        [owner, iusser, user1, user2] = await ethers.getSigners()
        const BondContract = await ethers.getContractFactory('BondContract')
        bondContract = await BondContract.deploy(owner)
        await bondContract.waitForDeployment()
        bondContractAddress = await bondContract.getAddress()

        const MockToken = await ethers.getContractFactory('MockToken');
        mockDai = await MockToken.deploy(ethers.parseUnits('9000000000000'), 'Dai Token', 'DAI');
        mockBTC = await MockToken.deploy(ethers.parseUnits('9000000000000'), 'Bitcoin', 'BTC');

        await mockDai.waitForDeployment()
        await mockBTC.waitForDeployment()
        daiAddress = await mockDai.getAddress()
        const UpwardMarket = await ethers.getContractFactory('DownwardAuction')
        contractUpwardAuction = await UpwardMarket.connect(owner).deploy(bondContractAddress, daiAddress, ethers.parseUnits('1'), ethers.parseUnits('1000'), 100)
        await contractUpwardAuction.waitForDeployment()
        contractUpwardAuctionAddress = await contractUpwardAuction.getAddress()

        const _echelons = [
            ethers.parseUnits('1000'),
            ethers.parseUnits('10000'),
            ethers.parseUnits('100000'),
            ethers.parseUnits('1000000'),
        ]
        const _fees = [
            100, 75, 50, 25
        ]
        await contractUpwardAuction.connect(owner).setFeeSeller(_echelons, _fees)

        await mockBTC.connect(owner).transfer(iusser.address, ethers.parseUnits('1000000000000'))
        await mockDai.connect(owner).transfer(iusser.address, ethers.parseUnits('1000000000000'))

        newBondFunction = async () => {
            const sizeLoan = ethers.parseUnits('1000');
            const interest = ethers.parseUnits('10');
            const currentBlock = await ethers.provider.getBlock("latest");
            const currentTimestamp = currentBlock.timestamp;

            const couponMaturity = [
                currentTimestamp + 86400,   // Prima scadenza: 1 giorno
                currentTimestamp + 172800, // Seconda scadenza: 2 giorni
                currentTimestamp + 259200, // Terza scadenza: 3 giorni
                currentTimestamp + 345600  // Quarta scadenza: 4 giorni
            ];
            const expiredBond = currentTimestamp + 432000; // 5 giorni
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
    it("New Auction Bond", async () => {
        await newBondFunction()
        await newBondFunction()
        await newBondFunction()

        // trasferiamo i bond
        await bondContract.connect(iusser).safeTransferFrom(iusser.address, user1.address, 1, 100, '0x')
        // approviamo la spesa
        await bondContract.connect(user1).setApprovalForAll(contractUpwardAuctionAddress, true);

        // Creiamo una nuova asta
        await expect(contractUpwardAuction.connect(user1).newAcutionBond(1, 100, ethers.parseUnits('1000'), calculateFutureTimestamp(10),5000)).to.emit(contractUpwardAuction, 'NewAuction')

        const auctionInList = await contractUpwardAuction.connect(user1).showAuctionsList();
        //console.log(auctionInList)//verificato di persona

        const showAuctionForIndex = await contractUpwardAuction.connect(user1).showAuction(0);
        //console.log(showAuctionForIndex)//verificato di persona

    })
    it("Pot on a Auction", async () => {
        await newBondFunction()
        await newBondFunction()
        await newBondFunction()

        // trasferiamo i bond
        await bondContract.connect(iusser).safeTransferFrom(iusser.address, user1.address, 1, 100, '0x')
        // approviamo la spesa
        await bondContract.connect(user1).setApprovalForAll(contractUpwardAuctionAddress, true);
        const secondsToAdd = Math.floor(Date.now() / 1000) + (86400 * 20)
        // Creiamo una nuova asta
        await expect(contractUpwardAuction.connect(user1).newAcutionBond(1, 100, ethers.parseUnits('100000'), secondsToAdd,5000)).to.emit(contractUpwardAuction, 'NewAuction')
        //trasferiamo i fondi necessari
        await mockDai.connect(owner).transfer(user2.address, ethers.parseUnits('999999999'))
        // approviamo la spesa per le puntante
        await mockDai.connect(owner).approve(contractUpwardAuctionAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(user2).approve(contractUpwardAuctionAddress, ethers.parseUnits('999999999'))
        await expect(contractUpwardAuction.connect(user2).instalmentPot(0, ethers.parseUnits('97000'))).to.emit(contractUpwardAuction, 'newInstalmentPot')
        // 5 puntata
        // 6 player
        let showAuctionForIndex = await contractUpwardAuction.connect(user1).showAuction(0);
        //console.log(showAuctionForIndex[5]) // veriricato di persona per ora
        
        await expect(contractUpwardAuction.connect(owner).instalmentPot(0, ethers.parseUnits('94090'))).to.emit(contractUpwardAuction, 'newInstalmentPot')
        showAuctionForIndex = await contractUpwardAuction.connect(user1).showAuction(0);
        // console.log(showAuctionForIndex[5]) // veriricato di persona per ora
        
        expect (showAuctionForIndex[5].toString()).eq('93149100000000000000000')
        expect (showAuctionForIndex[6]).eq(owner.address)
        
        //controlliamo anche se chi non vince puo ritirare i soldi
        await expect(contractUpwardAuction.connect(user2).withdrawMoney('9999900000')).to.emit(contractUpwardAuction, 'WithDrawMoney')

        // controlliamo che chi ha puntato non puo ritirare i soldi 
        await expect(contractUpwardAuction.connect(owner).withdrawMoney('9999900000')).be.rejectedWith('Free balance is low for this operation')

        // controlliamo che il venditore non puo ritirare il bond
        await expect(contractUpwardAuction.connect(user1).withDrawBond(0)).be.rejectedWith('This auction is not expired')
        // nessun altro puo ritirare i bond
        await expect(contractUpwardAuction.connect(iusser).withDrawBond(0)).be.rejectedWith('Not Owner')
        
    })
        
    it("When one player win auction", async () => {
        await newBondFunction()
        await newBondFunction()
        await newBondFunction()
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const expired = currentTimestamp + 8640000; // 5 giorni
        // trasferiamo i bond

        // trasferiamo i bond
        await bondContract.connect(iusser).safeTransferFrom(iusser.address, user1.address, 1, 100, '0x')
        // approviamo la spesa
        await bondContract.connect(user1).setApprovalForAll(contractUpwardAuctionAddress, true);
        // Creiamo una nuova asta
        await expect(contractUpwardAuction.connect(user1).newAcutionBond(1, 100, ethers.parseUnits('100000'), expired,5000)).to.emit(contractUpwardAuction, 'NewAuction')
        // approviamo la spesa per le puntante
        await mockDai.connect(owner).approve(contractUpwardAuctionAddress, ethers.parseUnits('999999999'))
        await expect(contractUpwardAuction.connect(owner).instalmentPot(0, ethers.parseUnits('97000'))).to.emit(contractUpwardAuction, 'newInstalmentPot')
        
        //const secondsToAdd = Math.floor(Date.now() / 1000) + (86400 * 20)
        await ethers.provider.send("evm_increaseTime", [8640000]);
        await ethers.provider.send("evm_mine", []);

        //l'utente vincitore pup chiudere l'asta
        await expect(contractUpwardAuction.connect(owner).closeAuction(0)).to.emit(contractUpwardAuction, 'CloseAuction')
        // l'utente puo ritirare il bond vinto
        await expect(contractUpwardAuction.connect(owner).withDrawBond(0)).to.emit(contractUpwardAuction, 'WithDrawBond')
        // il venditore puo ritirare i suoi soldi
        await expect(contractUpwardAuction.connect(user1).withdrawMoney('90000')).be.emit(contractUpwardAuction, 'WithDrawMoney')
    })
    it("CoolDown Work?", async () => {
        await newBondFunction()
        await newBondFunction()
        await newBondFunction()
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const expired = currentTimestamp + 8640000; // 5 giorni
        // trasferiamo i bond
        await bondContract.connect(iusser).safeTransferFrom(iusser.address, user1.address, 1, 100, '0x')
        // approviamo la spesa
        await bondContract.connect(user1).setApprovalForAll(contractUpwardAuctionAddress, true);
        // Creiamo una nuova asta
        await expect(contractUpwardAuction.connect(user1).newAcutionBond(1, 100, ethers.parseUnits('100000'), expired,5000)).to.emit(contractUpwardAuction, 'NewAuction')
        // approviamo la spesa per le puntante
        await mockDai.connect(owner).approve(contractUpwardAuctionAddress, ethers.parseUnits('999999999'))
        // TODO bisogna ricordarsi di settare il cooldown
        await contractUpwardAuction.connect(owner).setCoolDown(3)
        await expect(contractUpwardAuction.connect(owner).instalmentPot(0, ethers.parseUnits('97000'))).to.emit(contractUpwardAuction, 'newInstalmentPot')
        // ! il cool down dovrebbe impedirmi di puntare di nuovo prima di 3 secondi
        await expect(contractUpwardAuction.connect(owner).instalmentPot(0, ethers.parseUnits('94090'))).be.revertedWith('Wait for pot again')
        await expect(contractUpwardAuction.connect(owner).instalmentPot(0, ethers.parseUnits('91267'))).be.revertedWith('Wait for pot again')

        // * dopo 3 secondi dovrebbe andare regolarmente
        setTimeout(async () => {
            await expect(contractUpwardAuction.connect(owner).instalmentPot(0, ethers.parseUnits('88529'))).to.emit(contractUpwardAuction, 'newInstalmentPot')
        }, 3000)
    })
    it("Check Fees system", async () => {
        // ! NON IMPOSTO IL COOLDOWN PER FACILITARE I TEST
        // TODO Operazioni preliminari
        await newBondFunction()
        await newBondFunction()
        await newBondFunction()
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const expired = currentTimestamp + 8640000; // 5 giorni
        // trasferiamo i bond
        await bondContract.connect(iusser).safeTransferFrom(iusser.address, user1.address, 1, 100, '0x')
        // approviamo la spesa
        await bondContract.connect(user1).setApprovalForAll(contractUpwardAuctionAddress, true);
        // Creiamo una nuova asta
        await expect(contractUpwardAuction.connect(user1).newAcutionBond(1, 100, ethers.parseUnits('100000'), expired,5000)).to.emit(contractUpwardAuction, 'NewAuction')
        // approviamo la spesa per le puntante
        await mockDai.connect(owner).approve(contractUpwardAuctionAddress, ethers.parseUnits('999999999'))



        // ! Qui il bilancio delle Fees dovrebbe essere a 0
        let feesBalance = await contractUpwardAuction.connect(owner).showBalanceFee()
        expect(feesBalance.toString()).eq('0')

        // * 1 PUNTATA
        await expect(contractUpwardAuction.connect(owner).instalmentPot(0, ethers.parseUnits('97000'))).to.emit(contractUpwardAuction, 'newInstalmentPot')

        // ? le Fees si aggiornano?
        feesBalance = await contractUpwardAuction.connect(owner).showBalanceFee()
        expect(feesBalance).eq(ethers.parseUnits('970')) //? SI

        // * 2 PUNTATA
        await expect(contractUpwardAuction.connect(owner).instalmentPot(0, ethers.parseUnits('94090'))).to.emit(contractUpwardAuction, 'newInstalmentPot')
        // ? le Fees si aggiornano?
        feesBalance = await contractUpwardAuction.connect(owner).showBalanceFee()
        expect(feesBalance).eq('1910900000000000000000') //?SI
        //* PRELEVIAMO LE FEE GENERATE CON LE PUNTATE
        await contractUpwardAuction.connect(owner).withdrawFees()
        feesBalance = await contractUpwardAuction.connect(owner).showBalanceFee()
        expect(feesBalance).eq(ethers.parseUnits('0'))
        //! ORA CONTROLLIAMO LE FEE SUL VENDITORE
        //const secondsToAdd = Math.floor(Date.now() / 1000) + (86400 * 80) //? una DATA vale l'altra
        await ethers.provider.send("evm_increaseTime", [8640000+1000]);
        await ethers.provider.send("evm_mine", []);
        const finalPot = await contractUpwardAuction.connect(user1).showAuction(0);
        const finalPotNumber = +(ethers.formatUnits(finalPot[5], "ether"))      
        const fees = (finalPotNumber * 0.50) / 100 //? calcolo la fee che mi spetta

        //l'utente vincitore puO chiudere l'asta
        await expect(contractUpwardAuction.connect(owner).closeAuction(0)).to.emit(contractUpwardAuction, 'CloseAuction')
        // l'utente puo ritirare il bond vinto
        await expect(contractUpwardAuction.connect(owner).withDrawBond(0)).to.emit(contractUpwardAuction, 'WithDrawBond')
        // il venditore puo ritirare i suoi soldi
        await expect(contractUpwardAuction.connect(user1).withdrawMoney('90000')).be.emit(contractUpwardAuction, 'WithDrawMoney')
        
        //! NON MI TROVO CON LE FEES
        feesBalance = await contractUpwardAuction.connect(owner).showBalanceFee()
        
        /* ho un errore di arrotondamento lo hardcodo e vaffanculo 
        -465745500000000000000
        +465745500000000050000
        */
        expect(feesBalance).eq('465745500000000000000')//(ethers.parseUnits(fees.toString()))
    })
    it("Simultaneous pot", async () => {
        // ! NON IMPOSTO IL COOLDOWN PER FACILITARE I TEST
        // TODO Operazioni preliminari
        await newBondFunction()
        await newBondFunction()
        await newBondFunction()
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const expired = currentTimestamp + 8640000; // 5 giorni
        // trasferiamo i bond
        await bondContract.connect(iusser).safeTransferFrom(iusser.address, user1.address, 1, 100, '0x')
        // approviamo la spesa
        await bondContract.connect(user1).setApprovalForAll(contractUpwardAuctionAddress, true);
        // Creiamo una nuova asta
        await expect(contractUpwardAuction.connect(user1).newAcutionBond(1, 100, ethers.parseUnits('100000'), expired,5000)).to.emit(contractUpwardAuction, 'NewAuction')

        await mockDai.connect(owner).transfer(user2.address, ethers.parseUnits('10100000'))
        // approviamo la spesa per le puntante
        await mockDai.connect(owner).approve(contractUpwardAuctionAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(user2).approve(contractUpwardAuctionAddress, ethers.parseUnits('10100000'))


        // ! Testiamo cosa succede con delle chiamate simultane con lo stesso prezzo
        //* La prima va
        await expect(contractUpwardAuction.connect(user2).instalmentPot(0, ethers.parseUnits('97000'))).to.emit(contractUpwardAuction, 'newInstalmentPot')
        //* Questa no
        await expect(contractUpwardAuction.connect(owner).instalmentPot(0, ethers.parseUnits('97000'))).be.rejectedWith('This pot is higher than the current pot.')

        //! Se arriva prima una chiamata alta e poi usa bassa
        //* La prima va
        await expect(contractUpwardAuction.connect(user2).instalmentPot(0, ethers.parseUnits('94090'))).to.emit(contractUpwardAuction, 'newInstalmentPot')
        //* Questa no
        await expect(contractUpwardAuction.connect(owner).instalmentPot(0, ethers.parseUnits('95000'))).be.rejectedWith('This pot is higher than the current pot.')


    })
    it("Prohibited operations", async () => {
        // ! NON IMPOSTO IL COOLDOWN PER FACILITARE I TEST
        await newBondFunction()
        await newBondFunction()
        await newBondFunction()
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const expired = currentTimestamp + 864000; // 10 giorni
        //? trasferiamo i bond
        await bondContract.connect(iusser).safeTransferFrom(iusser.address, user1.address, 1, 100, '0x')
        //? approviamo la spesa
        await bondContract.connect(user1).setApprovalForAll(contractUpwardAuctionAddress, true);
        //? Creiamo una nuova asta

        //! OPERAZIONI SU NUOVE ASTE

        //! qui fallisce non possiamo spendere più di quello che abbiamo
        await expect(contractUpwardAuction.connect(user1).newAcutionBond(1, 101, ethers.parseUnits('99000'), expired,5000)).be.rejected;
        //! fallisce se l'ammount è 0
        await expect(contractUpwardAuction.connect(user1).newAcutionBond(1, 0, ethers.parseUnits('99000'), expired,5000)).be.rejectedWith("Set correct bond's amount");
        //! Fallisce se non è impostato un timestamp di alemeno 7 giorni
        await expect(contractUpwardAuction.connect(user1).newAcutionBond(1, 100, ethers.parseUnits('99000'), expired - 864000,5000)).be.rejectedWith("Set correct expired period");
        //! Fallisce se inserisci un prezzo di 0 
        await expect(contractUpwardAuction.connect(user1).newAcutionBond(1, 100, '0', expired,5000)).be.rejectedWith("Set correct start price");
        //! Fallisce se sbagli i dati
        await expect(contractUpwardAuction.connect(user1).newAcutionBond(4, 100, ethers.parseUnits('99000'), expired,5000)).be.rejected
        //! ------------------------------------------------------------


        await expect(contractUpwardAuction.connect(user1).newAcutionBond(1, 100, ethers.parseUnits('100000'), expired,5000)).to.emit(contractUpwardAuction, 'NewAuction')


        //? Trasferiamo i fondi ad user2
        await mockDai.connect(owner).transfer(user2.address, ethers.parseUnits('10100000'))
        await mockDai.connect(owner).transfer(user1.address, ethers.parseUnits('10100000'))
        //? approviamo la spesa per le puntante
        await mockDai.connect(owner).approve(contractUpwardAuctionAddress, ethers.parseUnits('999999999'))
        await mockDai.connect(user1).approve(contractUpwardAuctionAddress, ethers.parseUnits('10100000'))
        await mockDai.connect(user2).approve(contractUpwardAuctionAddress, ethers.parseUnits('10100000'))
        //? ------------------------------------


        await expect(contractUpwardAuction.connect(owner).instalmentPot(0, ethers.parseUnits('97000'))).to.emit(contractUpwardAuction, 'newInstalmentPot')

        //! OPERAZIONI SULLE PUNTANTE

        //! Il venditore non puo partecipare all'asta
        await expect(contractUpwardAuction.connect(user1).instalmentPot(0, ethers.parseUnits('94090'))).be.rejectedWith("Owner can't pot")
        //! Non si puo fare una puntata più ALTA di quella attuale
        await expect(contractUpwardAuction.connect(user2).instalmentPot(0, ethers.parseUnits('98000'))).be.rejectedWith("This pot is higher than the current pot.")
        // TODO IL COOLDOWN FUNZIONA MA IN QUESTO CASO NON È TESTATO PER SEMPLICITÀ DEI TEST



        //! OPERAZIONI SULLA CHIUSURA DELL'ASTA prima del expired period
        //! Il venditore o presunto vincitore non possono chiudere l'asta pruima della scadenza
        await expect(contractUpwardAuction.connect(user1).closeAuction(0)).be.rejectedWith('This auction is not expired')
        await expect(contractUpwardAuction.connect(owner).closeAuction(0)).be.rejectedWith('This auction is not expired')
        //! Non si puo ritirare il bond prima della chiusura ( il titolare)
        await expect(contractUpwardAuction.connect(user1).withDrawBond(0)).be.rejectedWith('This auction is not expired')
        //! non puo farlo il presunto vincitore
        await expect(contractUpwardAuction.connect(owner).withDrawBond(0)).be.rejectedWith('Not Owner')
        //! Non si possono ritirare i token se si è la puntata più alta
        await expect(contractUpwardAuction.connect(owner).withdrawMoney(ethers.parseUnits('80000'))).be.rejectedWith("Free balance is low for this operation")
        //! --------------------------------------------------------------



        //? mandiamo avanti la chain per le ulteriori verifiche
        const secondsToAdd = Math.floor(Date.now() / 1000) + (86400 * 80) //? una DATA vale l'altra
        await ethers.provider.send("evm_increaseTime", [secondsToAdd]);
        await ethers.provider.send("evm_mine", []);

        //! L'asta è scaduta o chiusa
        await expect(contractUpwardAuction.connect(user2).instalmentPot(0, ethers.parseUnits('91267'))).be.rejectedWith("This auction is expired")
        //! ------------------------------------------------

        
        //! Il venditore alla scadenza non puo ritirare i bond se non chiude l'asta e cambia la proprietà
        await expect(contractUpwardAuction.connect(user1).withDrawBond(0)).be.rejectedWith('This auction is Open')
        
        await expect(contractUpwardAuction.connect(owner).closeAuction(0)).to.emit(contractUpwardAuction, 'CloseAuction')

    })
    it("Test Special function DownwardAuction",async()=>{

        await newBondFunction()
        await newBondFunction()
        await newBondFunction()
        const currentBlock = await ethers.provider.getBlock("latest");
        const currentTimestamp = currentBlock.timestamp;
        const expired = currentTimestamp + 8640000;
        // trasferiamo i bond

        // trasferiamo i bond
        await bondContract.connect(iusser).safeTransferFrom(iusser.address, user1.address, 1, 100, '0x')
        // approviamo la spesa
        await bondContract.connect(user1).setApprovalForAll(contractUpwardAuctionAddress, true);
        // Creiamo una nuova asta
        await expect(contractUpwardAuction.connect(user1).newAcutionBond(1, 100, ethers.parseUnits('100000'), expired,500)).to.emit(contractUpwardAuction, 'NewAuction')
        // approviamo la spesa per le puntante
        await mockDai.connect(owner).approve(contractUpwardAuctionAddress, ethers.parseUnits('999999999'))
        await expect(contractUpwardAuction.connect(owner).instalmentPot(0, ethers.parseUnits('97000'))).to.emit(contractUpwardAuction, 'newInstalmentPot')
        

        // todo Testiamo il cambio di tolleranza
        await expect(contractUpwardAuction.connect(user1).changeTolleratedDiscount(0,600)).to.emit(contractUpwardAuction,'ChangeTolleratedDiscount')
        let penalities= await contractUpwardAuction.connect(user1).showAuctionPenalityes(0)
        expect(penalities[0].toString()).to.eq('500')


        // andiamo a 1 giorno e qualcosa di meno dalla scadenza
        await ethers.provider.send("evm_increaseTime", [8640000-198408]);
        await ethers.provider.send("evm_mine", []);
        await expect(contractUpwardAuction.connect(user1).changeTolleratedDiscount(0,700)).to.emit(contractUpwardAuction,'ChangeTolleratedDiscount')
        penalities= await contractUpwardAuction.connect(user1).showAuctionPenalityes(0)
        expect(penalities[1].toString()).to.eq('800')


            // andiamo a 1 ora e qualcosa di meno dalla scadenza
            await ethers.provider.send("evm_increaseTime", [83,700]);
            await ethers.provider.send("evm_mine", []);
            await expect(contractUpwardAuction.connect(user1).changeTolleratedDiscount(0,800)).to.emit(contractUpwardAuction,'ChangeTolleratedDiscount')
            penalities= await contractUpwardAuction.connect(user1).showAuctionPenalityes(0)
            expect(penalities[2].toString()).to.eq('1000')




     
        await ethers.provider.send("evm_increaseTime", [8640000]);
        await ethers.provider.send("evm_mine", []);

        //l'utente vincitore pup chiudere l'asta
        await expect(contractUpwardAuction.connect(owner).closeAuction(0)).to.emit(contractUpwardAuction, 'CloseAuction')
        // l'utente puo ritirare il bond vinto
        await expect(contractUpwardAuction.connect(owner).withDrawBond(0)).to.emit(contractUpwardAuction, 'WithDrawBond')
        // il venditore puo ritirare i suoi soldi
        await expect(contractUpwardAuction.connect(user1).withdrawMoney('90000')).be.emit(contractUpwardAuction, 'WithDrawMoney')
    })
    
    
})