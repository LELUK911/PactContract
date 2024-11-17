const { ethers } = require("hardhat");

async function main() {
    const latestBlock = await ethers.provider.getBlock("latest");
    console.log("Current blockchain timestamp:", latestBlock.timestamp);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
