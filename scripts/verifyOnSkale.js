const { run, ethers } = require("hardhat");
require("dotenv").config();

// Configurazioni
const SKALE_EXPLORER_URL = "https://juicy-low-small-testnet.explorer.testnet.skalenodes.com/address";

async function main() {
    const owner = "0x9E157eD74a826D93318F2a3669917A1fC827358d";

    const pact = '0x9Ed2C7a27CD28952E79d0d2c5959695608E30eD8'
    const forge = '0x58656c977f96954eD2935Ba35266F1fdA7aeDFcc'
    const rise = '0xF83d5825BCb3767f508D3442e022D10d402d3032'
    const fall = '0x213683E24830414527c4f825B28A5aBc7857D468'
    const mdai = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512'
    const mWETH = '0x5FbDB2315678afecb367f032d93F642f64180aa3'
    const mBTC = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'

    // Verifica Iron Pact
    try {
        await run("verify:verify", {
            address: pact,
            constructorArguments: [owner],
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
                100
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
                100
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