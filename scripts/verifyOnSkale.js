const { run, ethers } = require("hardhat");
require("dotenv").config();

// Configurazioni
const SKALE_EXPLORER_URL = "https://juicy-low-small-testnet.explorer.testnet.skalenodes.com/address";

async function main() {
    const owner = "0x9E157eD74a826D93318F2a3669917A1fC827358d";

    const helperPact = "0xBA986024B3D52C97c137FFd0C0CdE4667367679E"
    const pact = '0xA54AB187eb479aebbDD2a89681b495DCd38BD0E5'
    const forge = '0x40aFB5F4B83cb2Fb21d9A407475BD2b3571410E2'
    const rise = '0x4b706DdEFeAF3dde66C2de36B3754748C2a35601'
    const fall = '0xB7c8351801db9F6AABb2B1242E889C643BAF6DD8'
    const mdai = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512'
    const mWETH = '0x5FbDB2315678afecb367f032d93F642f64180aa3'
    const mBTC = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'



        // Verifica Helper Pact
        try {
            await run("verify:verify", {
                address: helperPact,
                constructorArguments: [],
                network: "skaleTesnet" // Specifica la rete SKALE
            });
            console.log(`✅ Helper Pact verified: ${SKALE_EXPLORER_URL}/${pact}`);
        } catch (error) {
            console.error("❌ Iron Pact verification failed:", error.message);
        }

    // Verifica Iron Pact
    try {
        await run("verify:verify", {
            address: pact,
            constructorArguments: [owner,owner,helperPact],
            network: "skaleTesnet" // Specifica la rete SKALE
        });
        console.log(`✅ Iron Pact verified: ${SKALE_EXPLORER_URL}/${pact}`);
    } catch (error) {
        console.error("❌ Iron Pact verification failed:", error.message);
    }

    // Verifica Iron Forge
    try {
        await run("verify:verify", {
            address: forge,
            constructorArguments: [pact],
            network: "skaleTesnet"
        });
        console.log(`✅ Iron Forge verified: ${SKALE_EXPLORER_URL}/${forge}`);
    } catch (error) {
        console.error("❌ Iron Forge verification failed:", error.message);
    }

    // Verifica Iron Rise
    try {
        await run("verify:verify", {
            address: rise,
            constructorArguments: [
                pact,
                mdai,
                ethers.parseUnits('1'),
                ethers.parseUnits('1000'),
                100,
                owner,
                owner,
                owner
            ],
            network: "skaleTesnet"
        });
        console.log(`✅ Iron Rise verified: ${SKALE_EXPLORER_URL}/${rise}`);
    } catch (error) {
        console.error("❌ Iron Rise verification failed:", error.message);
    }

    // Verifica Iron Fall
    try {
        await run("verify:verify", {
            address: fall,
            constructorArguments: [
                pact,
                mdai,
                ethers.parseUnits('1'),
                ethers.parseUnits('1000'),
                100,
                owner,
                owner,
                owner
            ],
            network: "skaleTesnet"
        });
        console.log(`✅ Iron Fall verified: ${SKALE_EXPLORER_URL}/${fall}`);
    } catch (error) {
        console.error("❌ Iron Fall verification failed:", error.message);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });