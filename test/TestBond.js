const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe('Test proxy Bond, stable version', () => {

    let bondContract,mockWETH, mockDai, mockBTC, owner, issuer, user1, user2;
    let bondContractAddress, daiAddress,btcAddress,WETHaddress;

    beforeEach(async () => {
        [owner, issuer, user1, user2] = await ethers.getSigners();

        const BondContractFactory = await ethers.getContractFactory("BondContract");
        bondContract = await upgrades.deployProxy(BondContractFactory, [owner.address], { initializer: 'initialize' });
        await bondContract.waitForDeployment();
        bondContractAddress = bondContract.address;


        const MockToken = await ethers.getContractFactory('MockToken');
        mockWETH = await MockToken.deploy(ethers.parseUnits('9000000000000'), 'WETH', 'WETH');
        mockDai = await MockToken.deploy(ethers.parseUnits('9000000000000'), 'Dai Token', 'DAI');
        mockBTC = await MockToken.deploy(ethers.parseUnits('9000000000000'), 'Bitcoin', 'BTC');

        await mockWETH.waitForDeployment()
        await mockDai.waitForDeployment()
        await mockBTC.waitForDeployment()
        daiAddress = await mockDai.getAddress()
        btcAddress = await mockBTC.getAddress()
        WETHaddress = await mockWETH.getAddress()


        //preliminar setting
        await bondContract.connect(owner).setWETHaddress(WETHaddress)
        await bondContract.connect(owner).setTransfertFee(ethers.parseUnits('0.01'))



        newBondFunction = async (_sizeLoan,_interest,couponMaturity,expiredBond,_collateralAmount,iusser) => {
            const sizeLoan = ethers.parseUnits(_sizeLoan);
            const interest = ethers.parseUnits(_interest);
            const currentBlock = await ethers.provider.getBlock("latest");
            const currentTimestamp = currentBlock.timestamp;

            /*
            const couponMaturity = [
                currentTimestamp + 86400,   // Prima scadenza: 1 giorno
                currentTimestamp + 172800, // Seconda scadenza: 2 giorni
                currentTimestamp + 259200, // Terza scadenza: 3 giorni
                currentTimestamp + 345600  // Quarta scadenza: 4 giorni
            ];
            */
            //const expiredBond = currentTimestamp + 432000; // 5 giorni
            const collateralAmount = ethers.parseUnits(_collateralAmount);
            const bondAmount = 100;
            const description = "Test bond";
            await mockBTC.connect(iusser).approve(bondContractAddress, ethers.parseUnits(_collateralAmount))

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

    it('deploys correctly and initializes variables', async () => {
        const bondID = await bondContract.connect(owner).viewBondID()
        const ownerAddress = await bondContract.connect(owner).owner()
        const wethAddress = await bondContract.connect(owner).showWETHaddress()
        const transferFee = await bondContract.connect(owner).showTransfertFee()
        
        expect(await bondID.toString()).to.eq('0')
        expect(ownerAddress).to.eq(owner.address)
        expect(wethAddress).to.eq(WETHaddress)
        expect(transferFee.toString()).to.eq((ethers.parseUnits('0.01')).toString())

    });

 

    // Aggiungi altri test seguendo la lista precedente
});
