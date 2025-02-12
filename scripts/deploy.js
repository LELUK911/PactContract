const { ethers } = require("hardhat")
require("dotenv").config()
const main = async () => {



    const provider = new ethers.JsonRpcProvider('https://rpc.ankr.com/eth_sepolia')
    const owner = new ethers.Wallet(process.env.PRIVATE_KEY, provider)


    const BondContractFactory = await ethers.getContractFactory("BondContract");
    const bondContract = await BondContractFactory.connect(owner).deploy(owner.address)
    await bondContract.waitForDeployment()
    const bondContractAddress = await bondContract.getAddress()

    const LaunchBondContract = await ethers.getContractFactory('BondLaunch')
    const launchBondContract = await LaunchBondContract.connect(owner).deploy(bondContractAddress)
    await launchBondContract.waitForDeployment()
    const launchBondContractAddress = await launchBondContract.getAddress()

    const MockToken = await ethers.getContractFactory('MockToken');
    const mockWETH = await MockToken.deploy(ethers.parseUnits('90000000000000000000'), 'WETH', 'WETH');
    const mockDai = await MockToken.deploy(ethers.parseUnits('90000000000000000000'), 'Dai Token', 'DAI');
    const mockBTC = await MockToken.deploy(ethers.parseUnits('90000000000000000000'), 'Bitcoin', 'BTC');

    await mockWETH.waitForDeployment()
    await mockDai.waitForDeployment()
    await mockBTC.waitForDeployment()

    const daiAddress = await mockDai.getAddress()
    const btcAddress = await mockBTC.getAddress()
    const WETHaddress = await mockWETH.getAddress()


    //? UPWARD DEPLOY AND PRELIMINAR ACTION
    const UpwardAuction = await ethers.getContractFactory('UpwardAuction')
    const upwardAuctionContract = await UpwardAuction.connect(owner).deploy(
        bondContractAddress,
        daiAddress,
        ethers.parseUnits('1'),//fixed Fee 1$
        ethers.parseUnits('1000'),// price Threshold 1000$
        100 //dinamicfee 1%
    )
    await upwardAuctionContract.waitForDeployment()
    const upwardAuctionContractAddress = await upwardAuctionContract.getAddress()

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
    const downwardAuctionContract = await downwardAuction.connect(owner).deploy(
        bondContractAddress,
        daiAddress,
        ethers.parseUnits('1'),//fixed Fee 1$
        ethers.parseUnits('1000'),// price Threshold 1000$
        100 //dinamicfee 1%
    )
    await downwardAuctionContract.waitForDeployment()
    const downwardAuctionContractAddress = await downwardAuctionContract.getAddress()
    await downwardAuctionContract.connect(owner).setFeeSeller(_echelons, _fees)

    //? set preliminar variable BondContract
    await bondContract.connect(owner).setMAX_COUPONS('6')
    await bondContract.connect(owner).setTransfertFee(ethers.parseUnits('0.01'))
    await bondContract.connect(owner).setlauncherContract(launchBondContractAddress)
    await bondContract.connect(owner).setlauncherContract(launchBondContractAddress)
    await bondContract.connect(owner).setWETHaddress(WETHaddress)
    await bondContract.connect(owner).setTreasuryAddress(owner.address) // Uguale all'owner per comodità nei test
    await bondContract.connect(owner).setEcosistemAddress(upwardAuctionContractAddress, true)
    await bondContract.connect(owner).setEcosistemAddress(downwardAuctionContractAddress, true)

    await upwardAuctionContract.connect(owner).setCoolDown(3)
    await downwardAuctionContract.connect(owner).setCoolDown(3)



    console.log("------------------------------------Address contract------------------------------")
    console.log(``)
    console.log(``)

    console.log(`Bond contract -> ${bondContractAddress}`)
    console.log(``)
    console.log(``)

    console.log(`Bond contract -> ${launchBondContractAddress}`)
    console.log(``)
    console.log(``)

    console.log(`Bond contract -> ${upwardAuctionContractAddress}`)
    console.log(``)
    console.log(``)

    console.log(`Bond contract -> ${downwardAuction}`)
    console.log(``)
    console.log(``)


    console.log('TUTTO DEPLOYATO SULLA TESNET bARTIO')
    console.log(``)
    console.log(`_________________________________________________________________________________________`)

}



main()
    .then(() => process.exit(0))
    .catch((e) => {
        console.log(e);
        process.exit(1)
    })