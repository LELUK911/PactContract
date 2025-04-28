const { ethers } = require("hardhat");
require("dotenv").config();

// Aggiungi un delay per evitare conflitti di nonce
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

const WETHaddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3"
const daiAddress  = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"
const btcAddress  = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"

const main = async () => {
    const provider = new ethers.JsonRpcProvider('https://testnet.skalenodes.com/v1/juicy-low-small-testnet');
    const owner = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

    //0 Deploy Helper Pact
    const HelperPact = await ethers.getContractFactory('HelperPact');
    const helperPACT = await HelperPact.connect(owner).deploy();
    await helperPACT.waitForDeployment();
    const helperPACTAddress = await helperPACT.getAddress();
    console.log("HelperPact deployed:", helperPACTAddress);
    await delay(15000); // Attendi 15 secondi



    // 1. Deploy PactContract
    const PactContractFactory = await ethers.getContractFactory("PactContract");
    const pactContract = await PactContractFactory.connect(owner).deploy(owner.address,owner.address,helperPACTAddress);
    await pactContract.waitForDeployment();
    const pactContractAddress = await pactContract.getAddress();
    console.log("PactContract deployed:", pactContractAddress);

    await delay(15000); // Attendi 15 secondi

    // 2. Deploy PactLaunch
    const LaunchPactContract = await ethers.getContractFactory('PactLaunch');
    const launchPactContract = await LaunchPactContract.connect(owner).deploy(pactContractAddress);
    await launchPactContract.waitForDeployment();
    const launchPactContractAddress = await launchPactContract.getAddress();
    console.log("PactLaunch deployed:", launchPactContractAddress);

    await delay(15000);
/*
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
*/
    // 4. Deploy UpwardAuction
    const UpwardAuction = await ethers.getContractFactory('UpwardAuction');
    const upwardAuctionContract = await UpwardAuction.connect(owner).deploy(
        pactContractAddress,
        daiAddress,
        ethers.parseUnits('1'),
        ethers.parseUnits('1000'),
        100,
        owner.address,
        owner.address,
        owner.address,
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
        pactContractAddress,
        daiAddress,
        ethers.parseUnits('1'),
        ethers.parseUnits('1000'),
        100,
        owner.address,
        owner.address,
        owner.address,
    );
    await downwardAuctionContract.waitForDeployment();
    const downwardAuctionContractAddress = await downwardAuctionContract.getAddress();
    console.log("DownwardAuction deployed:", downwardAuctionContractAddress);

    await delay(15000);
    // 7. Configurazione DownwardAuction
    await downwardAuctionContract.connect(owner).setFeeSeller(_echelons, _fees);
    console.log("DownwardAuction configured");

    await delay(15000);


    // 8. Configurazione finale PactContract
    await pactContract.connect(owner).setMAX_COUPONS('6');
    await delay(5000);
    await pactContract.connect(owner).setTransfertFee(ethers.parseUnits('0.01'));
    await delay(5000);
    await pactContract.connect(owner).setlauncherContract(launchPactContractAddress);
    await delay(5000);
    await pactContract.connect(owner).setWETHaddress(WETHaddress);
    await delay(5000);
    await pactContract.connect(owner).setTreasuryAddress(owner.address);
    await delay(5000);
    await pactContract.connect(owner).setEcosistemAddress(upwardAuctionContractAddress, true);
    await delay(5000);
    await pactContract.connect(owner).setEcosistemAddress(downwardAuctionContractAddress, true);
    await delay(5000);

    await upwardAuctionContract.connect(owner).setCoolDown(3);
    await delay(5000);

    await downwardAuctionContract.connect(owner).setCoolDown(3);

    console.log("✅ Tutti i contratti configurati correttamente!");


    console.log("------------------------------------Address contract------------------------------")
    console.log(``)
    console.log(``)

    console.log(`Pact contract -> ${pactContractAddress}`)
    console.log(``)
    console.log(``)

    console.log(`Pact contract -> ${launchPactContractAddress}`)
    console.log(``)
    console.log(``)

    console.log(`Pact contract -> ${upwardAuctionContractAddress}`)
    console.log(``)
    console.log(``)

    console.log(`Pact contract -> ${downwardAuctionContractAddress}`)
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




























