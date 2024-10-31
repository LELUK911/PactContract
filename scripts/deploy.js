const { ethers } = require("hardhat")

const main = async ()=>{

    const BondContract = await ethers.getContractFactory('BondContract');

    const bondContract = await BondContract.deploy();

    await bondContract.waitForDeployment()

    console.log(`Contract deployed to: ${ await bondContract.getAddress()}`)
}


main()
    .then(()=> process.exit(0))
    .catch((e)=>{
        console.log(e);
        process.exit(1)
    })