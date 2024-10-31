const { expect } = require("chai");
const { ethers } = require("hardhat");




describe('Test finale con le fee', () => {
    let bondContract, mockDai, mockBTC;
    let owner, issuer, user1, user2;
    let bondContractAddress;

    let bondPagatoRegolarmente, bondCedoleInsolute, bondPrestitoInsoluto


    beforeEach(async () => {
        const BondContract = await ethers.getContractFactory('BondContract')
        const MockToken = await ethers.getContractFactory('MockToken');

        [owner, issuer, user1, user2] = await ethers.getSigners()
        mockDai = await MockToken.deploy(ethers.parseUnits('1000000000000'), 'Dai Token', 'DAI');
        mockBTC = await MockToken.deploy(ethers.parseUnits('1000000000000'), 'Bitcoin', 'BTC');
        bondContract = await BondContract.deploy(owner);

        await mockDai.waitForDeployment()
        await mockBTC.waitForDeployment()
        await bondContract.waitForDeployment()

        bondContractAddress = await bondContract.getAddress()

        await mockBTC.connect(owner).transfer(issuer.address, ethers.parseUnits('1000000000000'))
        await mockDai.connect(owner).transfer(issuer.address, ethers.parseUnits('1000000000000'))

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

        await mockBTC.connect(issuer).approve(bondContractAddress, ethers.parseUnits('1000000000'))

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

        await mockDai.connect(issuer).approve(bondContractAddress, ethers.parseUnits('1000000000'))


        const bondDetails = await bondContract.showDeatailBondForId(0)
        expect(bondDetails.issuer).to.equal(issuer.address);
        expect(bondDetails.sizeLoan).to.equal(sizeLoan);
        //expect(bondDetails.collateral).to.equal(collateralAmount);

        await bondContract.connect(issuer).safeTransferFrom(issuer.address, user1.address, 0, 100, "0x");

        bondPagatoRegolarmente = async () => {
            const versamento = ethers.parseUnits('104000')
            //await bondContract.connect(issuer).safeTransferFrom(issuer.address, user1.address, 0, 100, "0x");

            await bondContract.connect(issuer).depositTokenForInterest(0, versamento);


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
        }
        bondCedoleInsolute = async () => {
            const versamento = ethers.parseUnits('3600')


            await bondContract.connect(issuer).depositTokenForInterest(0, versamento);


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


            await bondContract.connect(issuer).depositTokenForInterest(0, ethers.parseUnits('1000000'));

            await expect(bondContract.connect(user1).claimLoan(0, 100)).to.emit(bondContract, "LoanClaimed");


            // Simula il passaggio di 90 giorni (7,776,000 secondi) dalla scadenza attuale
            await ethers.provider.send("evm_increaseTime", [8208000]);  // 90 giorni più 5 giorni già aggiunti
            await ethers.provider.send("evm_mine");


            await expect(bondContract.connect(issuer).withdrawCollateral(0)).to.emit(bondContract, "CollateralWithdrawn");
        }
        bondPrestitoInsoluto = async () => {
            const versamento = ethers.parseUnits('3600')
            //await bondContract.connect(issuer).safeTransferFrom(issuer.address, user1.address, 0, 100, "0x");

            await bondContract.connect(issuer).depositTokenForInterest(0, versamento);


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



            await expect(bondContract.connect(user1).claimLoan(0, 100)).to.emit(bondContract, "LiquitationCollateralBondExpired");


            // Simula il passaggio di 90 giorni (7,776,000 secondi) dalla scadenza attuale
            await ethers.provider.send("evm_increaseTime", [8208000]);  // 90 giorni più 5 giorni già aggiunti
            await ethers.provider.send("evm_mine");


            await expect(bondContract.connect(issuer).withdrawCollateral(0)).to.emit(bondContract, "CollateralWithdrawn");
        }

    })

    it("Controllo che tutte le normali funzioni ovviamente funzionino", async () => {
        
        await bondPagatoRegolarmente();
        
        const mockBTCAddress = await mockBTC.getAddress()
        await expect(bondContract.connect(owner).withdrawContractBalance(mockBTCAddress)).to.emit(bondContract,'WitrawBalanceContracr')
        
        const balanceOwner = await mockBTC.connect(owner).balanceOf(owner.address)
        console.log(`Bilancio del owner -> ${balanceOwner.toString()}`)
        //console.log(`Bilancio del owner -> ${balanceOwner}`)
    
    })


})