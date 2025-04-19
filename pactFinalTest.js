const { expect } = require("chai");
const { ethers } = require("hardhat");




describe('Test finale con le fee', () => {
    let pactContract, mockDai, mockBTC;
    let owner, debtor, user1, user2;
    let bondContractAddress;

    let bondPagatoRegolarmente, bondCedoleInsolute, bondPrestitoInsoluto


    beforeEach(async () => {
        const PactContract = await ethers.getContractFactory('PactContract')
        const MockToken = await ethers.getContractFactory('MockToken');

        [owner, debtor, user1, user2] = await ethers.getSigners()
        mockDai = await MockToken.deploy(ethers.parseUnits('1000000000000'), 'Dai Token', 'DAI');
        mockBTC = await MockToken.deploy(ethers.parseUnits('1000000000000'), 'Bitcoin', 'BTC');
        pactContract = await PactContract.deploy(owner);

        await mockDai.waitForDeployment()
        await mockBTC.waitForDeployment()
        await pactContract.waitForDeployment()

        bondContractAddress = await pactContract.getAddress()

        await mockBTC.connect(owner).transfer(debtor.address, ethers.parseUnits('1000000000000'))
        await mockDai.connect(owner).transfer(debtor.address, ethers.parseUnits('1000000000000'))

        const sizeLoan = ethers.parseUnits('1000');
        const interest = ethers.parseUnits('10');
        const rewardMaturity = [
            Math.floor(Date.now() / 1000) + 86400,    // Prima scadenza: 1 giorno
            Math.floor(Date.now() / 1000) + 172800,   // Seconda scadenza: 2 giorni
            Math.floor(Date.now() / 1000) + 259200,   // Terza scadenza: 3 giorni
            Math.floor(Date.now() / 1000) + 345600    // Quarta scadenza: 4 giorni
        ];
        const expiredPact = Math.floor(Date.now() / 1000) + 432000;
        const collateralAmount = ethers.parseUnits('8000');
        const bondAmount = 100;
        const description = "Test pact";

        await mockBTC.connect(debtor).approve(bondContractAddress, ethers.parseUnits('1000000000'))

        await expect(
            pactContract.connect(debtor).createNewPact(
                debtor.address,
                await mockDai.getAddress(),
                sizeLoan,
                interest,
                rewardMaturity,
                expiredPact,
                await mockBTC.getAddress(),
                collateralAmount,
                bondAmount,
                description
            )
        ).to.emit(pactContract, "PactCreated");

        await mockDai.connect(debtor).approve(bondContractAddress, ethers.parseUnits('1000000000'))


        const bondDetails = await pactContract.showDeatailPactForId(0)
        expect(bondDetails.debtor).to.equal(debtor.address);
        expect(bondDetails.sizeLoan).to.equal(sizeLoan);
        //expect(bondDetails.collateral).to.equal(collateralAmount);

        await pactContract.connect(debtor).safeTransferFrom(debtor.address, user1.address, 0, 100, "0x");

        bondPagatoRegolarmente = async () => {
            const versamento = ethers.parseUnits('104000')
            //await pactContract.connect(debtor).safeTransferFrom(debtor.address, user1.address, 0, 100, "0x");

            await pactContract.connect(debtor).depositTokenForInterest(0, versamento);


            // Simula il passaggio del tempo di 1 giorno
            await ethers.provider.send("evm_increaseTime", [86400]);
            await ethers.provider.send("evm_mine");

            // Coso richiede la cedola
            await expect(pactContract.connect(user1).claimRewardForUSer(0, 0)).to.emit(pactContract, "RewardClaimed");

            await ethers.provider.send("evm_increaseTime", [172800]);
            await ethers.provider.send("evm_mine");
            await expect(pactContract.connect(user1).claimRewardForUSer(0, 1)).to.emit(pactContract, "RewardClaimed");

            await ethers.provider.send("evm_increaseTime", [259200]);
            await ethers.provider.send("evm_mine");
            await expect(pactContract.connect(user1).claimRewardForUSer(0, 2)).to.emit(pactContract, "RewardClaimed");

            await ethers.provider.send("evm_increaseTime", [345600]);
            await ethers.provider.send("evm_mine");
            await expect(pactContract.connect(user1).claimRewardForUSer(0, 3)).to.emit(pactContract, "RewardClaimed");


            await ethers.provider.send("evm_increaseTime", [432000]);
            await ethers.provider.send("evm_mine")



            await expect(pactContract.connect(user1).claimLoan(0, 100)).to.emit(pactContract, "LoanClaimed");


            // Simula il passaggio di 90 giorni (7,776,000 secondi) dalla scadenza attuale
            await ethers.provider.send("evm_increaseTime", [8208000]);  // 90 giorni più 5 giorni già aggiunti
            await ethers.provider.send("evm_mine");


            await expect(pactContract.connect(debtor).withdrawCollateral(0)).to.emit(pactContract, "CollateralWithdrawn");
        }
        bondCedoleInsolute = async () => {
            const versamento = ethers.parseUnits('3600')


            await pactContract.connect(debtor).depositTokenForInterest(0, versamento);


            // Simula il passaggio del tempo di 1 giorno
            await ethers.provider.send("evm_increaseTime", [86400]);
            await ethers.provider.send("evm_mine");

            // Coso richiede la cedola
            await expect(pactContract.connect(user1).claimRewardForUSer(0, 0)).to.emit(pactContract, "RewardClaimed");

            await ethers.provider.send("evm_increaseTime", [172800]);
            await ethers.provider.send("evm_mine");
            await expect(pactContract.connect(user1).claimRewardForUSer(0, 1)).to.emit(pactContract, "RewardClaimed");

            await ethers.provider.send("evm_increaseTime", [259200]);
            await ethers.provider.send("evm_mine");
            await expect(pactContract.connect(user1).claimRewardForUSer(0, 2)).to.emit(pactContract, "RewardClaimed");

            await ethers.provider.send("evm_increaseTime", [345600]);
            await ethers.provider.send("evm_mine");
            await expect(pactContract.connect(user1).claimRewardForUSer(0, 3)).to.emit(pactContract, "RewardClaimed");


            await ethers.provider.send("evm_increaseTime", [432000]);
            await ethers.provider.send("evm_mine")


            await pactContract.connect(debtor).depositTokenForInterest(0, ethers.parseUnits('1000000'));

            await expect(pactContract.connect(user1).claimLoan(0, 100)).to.emit(pactContract, "LoanClaimed");


            // Simula il passaggio di 90 giorni (7,776,000 secondi) dalla scadenza attuale
            await ethers.provider.send("evm_increaseTime", [8208000]);  // 90 giorni più 5 giorni già aggiunti
            await ethers.provider.send("evm_mine");


            await expect(pactContract.connect(debtor).withdrawCollateral(0)).to.emit(pactContract, "CollateralWithdrawn");
        }
        bondPrestitoInsoluto = async () => {
            const versamento = ethers.parseUnits('3600')
            //await pactContract.connect(debtor).safeTransferFrom(debtor.address, user1.address, 0, 100, "0x");

            await pactContract.connect(debtor).depositTokenForInterest(0, versamento);


            // Simula il passaggio del tempo di 1 giorno
            await ethers.provider.send("evm_increaseTime", [86400]);
            await ethers.provider.send("evm_mine");

            // Coso richiede la cedola
            await expect(pactContract.connect(user1).claimRewardForUSer(0, 0)).to.emit(pactContract, "RewardClaimed");

            await ethers.provider.send("evm_increaseTime", [172800]);
            await ethers.provider.send("evm_mine");
            await expect(pactContract.connect(user1).claimRewardForUSer(0, 1)).to.emit(pactContract, "RewardClaimed");

            await ethers.provider.send("evm_increaseTime", [259200]);
            await ethers.provider.send("evm_mine");
            await expect(pactContract.connect(user1).claimRewardForUSer(0, 2)).to.emit(pactContract, "RewardClaimed");

            await ethers.provider.send("evm_increaseTime", [345600]);
            await ethers.provider.send("evm_mine");
            await expect(pactContract.connect(user1).claimRewardForUSer(0, 3)).to.emit(pactContract, "RewardClaimed");


            await ethers.provider.send("evm_increaseTime", [432000]);
            await ethers.provider.send("evm_mine")



            await expect(pactContract.connect(user1).claimLoan(0, 100)).to.emit(pactContract, "LiquitationCollateralPactExpired");


            // Simula il passaggio di 90 giorni (7,776,000 secondi) dalla scadenza attuale
            await ethers.provider.send("evm_increaseTime", [8208000]);  // 90 giorni più 5 giorni già aggiunti
            await ethers.provider.send("evm_mine");


            await expect(pactContract.connect(debtor).withdrawCollateral(0)).to.emit(pactContract, "CollateralWithdrawn");
        }

    })

    it("Controllo che tutte le normali funzioni ovviamente funzionino", async () => {
        
        await bondPagatoRegolarmente();
        
        const mockBTCAddress = await mockBTC.getAddress()
        await expect(pactContract.connect(owner).withdrawContractBalance(mockBTCAddress)).to.emit(pactContract,'WitrawBalanceContracr')
        
        const balanceOwner = await mockBTC.connect(owner).balanceOf(owner.address)
        console.log(`Bilancio del owner -> ${balanceOwner.toString()}`)
        //console.log(`Bilancio del owner -> ${balanceOwner}`)
    
    })


})