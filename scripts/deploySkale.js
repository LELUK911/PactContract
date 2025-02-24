const { ethers } = require("hardhat");
require("dotenv").config();

// Aggiungi un delay per evitare conflitti di nonce
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

const main = async () => {
    const provider = new ethers.JsonRpcProvider('https://testnet.skalenodes.com/v1/juicy-low-small-testnet');
    const owner = new ethers.Wallet(process.env.PRIVATE_KEY, provider);


    // 1. Deploy BondContract
    const BondContractFactory = await ethers.getContractFactory("BondContract");
    const bondContract = await BondContractFactory.connect(owner).deploy(owner.address);
    await bondContract.waitForDeployment();
    const bondContractAddress = await bondContract.getAddress();
    console.log("BondContract deployed:", bondContractAddress);

    await delay(15000); // Attendi 15 secondi

    // 2. Deploy BondLaunch
    const LaunchBondContract = await ethers.getContractFactory('BondLaunch');
    const launchBondContract = await LaunchBondContract.connect(owner).deploy(bondContractAddress);
    await launchBondContract.waitForDeployment();
    const launchBondContractAddress = await launchBondContract.getAddress();
    console.log("BondLaunch deployed:", launchBondContractAddress);

    await delay(15000);

    // 3. Deploy Mock Tokens (sequenziale)
    const MockToken = await ethers.getContractFactory('MockToken');
    const mockWETH = await MockToken.deploy(ethers.parseUnits('90000000000000000000'), 'WETH', 'WETH');
    await mockWETH.waitForDeployment();
    const WETHaddress = await mockWETH.getAddress();
    console.log("WETH deployed:", WETHaddress);

    await delay(10000);

    const mockDai = await MockToken.deploy(ethers.parseUnits('90000000000000000000'), 'Dai Token', 'DAI');
    await mockDai.waitForDeployment();
    const daiAddress = await mockDai.getAddress();
    console.log("DAI deployed:", daiAddress);

    await delay(10000);

    const mockBTC = await MockToken.deploy(ethers.parseUnits('90000000000000000000'), 'Bitcoin', 'BTC');
    await mockBTC.waitForDeployment();
    const btcAddress = await mockBTC.getAddress();
    console.log("BTC deployed:", btcAddress);

    await delay(15000);

    // 4. Deploy UpwardAuction
    const UpwardAuction = await ethers.getContractFactory('UpwardAuction');
    const upwardAuctionContract = await UpwardAuction.connect(owner).deploy(
        bondContractAddress,
        daiAddress,
        ethers.parseUnits('1'),
        ethers.parseUnits('1000'),
        100
    );
    await upwardAuctionContract.waitForDeployment();
    const upwardAuctionContractAddress = await upwardAuctionContract.getAddress();
    console.log("UpwardAuction deployed:", upwardAuctionContractAddress);

    await delay(15000);

    // 5. Configurazione UpwardAuction
    const _echelons = [
        ethers.parseUnits('1000'),
        ethers.parseUnits('10000'),
        ethers.parseUnits('100000'),
        ethers.parseUnits('1000000'),
    ];
    const _fees = [100, 75, 50, 25];
    await upwardAuctionContract.connect(owner).setFeeSeller(_echelons, _fees);
    console.log("UpwardAuction configured");

    await delay(15000);

    // 6. Deploy DownwardAuction
    const downwardAuction = await ethers.getContractFactory('DownwardAuction');
    const downwardAuctionContract = await downwardAuction.connect(owner).deploy(
        bondContractAddress,
        daiAddress,
        ethers.parseUnits('1'),
        ethers.parseUnits('1000'),
        100
    );
    await downwardAuctionContract.waitForDeployment();
    const downwardAuctionContractAddress = await downwardAuctionContract.getAddress();
    console.log("DownwardAuction deployed:", downwardAuctionContractAddress);

    await delay(15000);
    // 7. Configurazione DownwardAuction
    await downwardAuctionContract.connect(owner).setFeeSeller(_echelons, _fees);
    console.log("DownwardAuction configured");

    await delay(15000);


    // 8. Configurazione finale BondContract
    await bondContract.connect(owner).setMAX_COUPONS('6');
    await delay(5000);
    await bondContract.connect(owner).setTransfertFee(ethers.parseUnits('0.01'));
    await delay(5000);
    await bondContract.connect(owner).setlauncherContract(launchBondContractAddress);
    await delay(5000);
    await bondContract.connect(owner).setWETHaddress(WETHaddress);
    await delay(5000);
    await bondContract.connect(owner).setTreasuryAddress(owner.address);
    await delay(5000);
    await bondContract.connect(owner).setEcosistemAddress(upwardAuctionContractAddress, true);
    await delay(5000);
    await bondContract.connect(owner).setEcosistemAddress(downwardAuctionContractAddress, true);
    await delay(5000);

    await upwardAuctionContract.connect(owner).setCoolDown(3);
    await delay(5000);

    await downwardAuctionContract.connect(owner).setCoolDown(3);

    console.log("✅ Tutti i contratti configurati correttamente!");


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

    console.log(`Bond contract -> ${downwardAuctionContractAddress}`)
    console.log(``)
    console.log(``)


    console.log(`mDaI -> ${daiAddress}`)
    console.log(``)
    console.log(``)

    console.log(`mBTC -> ${btcAddress}`)
    console.log(``)
    console.log(``)

    console.log(`mWETH -> ${WETHaddress}`)
    console.log(``)
    console.log(``)


    console.log('TUTTO DEPLOYATO SULLA TESNET Skale Europa')
    console.log(``)
    console.log(`_________________________________________________________________________________________`)


};

main()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error("❌ Errore:", e);
        process.exit(1);
    });




























