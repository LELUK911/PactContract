const { run, ethers } = require("hardhat");
require("dotenv").config();

async function main() {
    const owner = "0x9E157eD74a826D93318F2a3669917A1fC827358d";


    const pact = '0x9c7F4DcABdFf2b91F801A3A9dCE48a2d4b16acB8'
    const forge = '0x897699D837C6b78Ef141813fC2C3932D70afF32D'
    const rise = '0x0eBE1D04eA58629b808410002c61e324Cd0aE5f3'
    const fall = '0xEAEB9f260f0d4bF00327B369dC9C944E4e51fC99'
    const mdai = '0xc48218e6c6Ad46E55739ab6D5E0fd2c075eaaff2'

    // Iron Pact
    try {
        await run("verify:verify", {
            address: pact,
            constructorArguments: [owner],
        });
        console.log("Iron pact")
        console.log(`✅ Contract verified: https://sepolia.etherscan.io/address/${pact}`);
    } catch (error) {
        console.error("❌ Verification failed:", error.message);
    }

    //IRON FORGE
    try {
        await run("verify:verify", {
            address: forge,
            constructorArguments: [pact],
        });
        console.log("Iron forge")
        console.log(`✅ Contract verified: https://sepolia.etherscan.io/address/${forge}`);
    } catch (error) {
        console.error("❌ Verification failed:", error.message);
    }

    //IRON RISE
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
        });
        console.log("Iron Rise")
        console.log(`✅ Contract verified: https://sepolia.etherscan.io/address/${rise}`);
    } catch (error) {
        console.error("❌ Verification failed:", error.message);
    }

    //IRON FALL
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
        });

        console.log(`✅ Contract verified: https://sepolia.etherscan.io/address/${fall}`);
    } catch (error) {
        console.error("❌ Verification failed:", error.message);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
