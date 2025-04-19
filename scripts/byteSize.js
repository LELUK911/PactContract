const hre = require("hardhat");

async function main() {
    const contractName = "PactContract"; // Nome esatto del contratto
    const artifact = await hre.artifacts.readArtifact(contractName);
    
    const bytecodeSize = artifact.deployedBytecode.length / 2; // Ogni byte è rappresentato da 2 caratteri esadecimali
    
    console.log(`Bytecode size: ${bytecodeSize} bytes`);
    console.log(`Contract size: ${(bytecodeSize / 1024).toFixed(2)} KB`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
