require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200, // Puoi aumentare questo numero se i contratti sono deployed una volta sola
          },
          viaIR: true, // Risolve il problema "Stack too deep"
          outputSelection: {
            "*": {
              "*": ["*"],
            },
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true, // Utile per contratti grandi durante i test
    },
    sepolia: {
      url: "https://rpc.ankr.com/eth_sepolia",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    skaleTesnet: {
      url: "https://testnet.skalenodes.com/v1/juicy-low-small-testnet",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};