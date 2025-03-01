require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require('@openzeppelin/hardhat-upgrades');
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 50
      },
      viaIR: false,
    },
  },
  networks: {
    berachain_testnet: {
      url: process.env.RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
    },
    sepolia: {
      url: 'https://rpc.ankr.com/eth_sepolia',
      accounts: [process.env.PRIVATE_KEY],
    },
    skaleTesnet: { // Mantieni lo stesso nome usato in customChains
      url: 'https://testnet.skalenodes.com/v1/juicy-low-small-testnet',
      accounts: [process.env.PRIVATE_KEY],
      chainId: 1444673419 // Aggiungi esplicitamente il chainId
    },
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY,
      skaleTesnet: "PLACEHOLDER" // Deve matchare il nome della rete
    },
    customChains: [
      {
        network: "skaleTesnet", // Nome deve corrispondere alla rete
        chainId: 1444673419, // Chain ID ufficiale di SKALE Testnet
        urls: {
          apiURL: "https://juicy-low-small-testnet.explorer.testnet.skalenodes.com/api",
          browserURL: "https://juicy-low-small-testnet.explorer.testnet.skalenodes.com"
        }
      }
    ]
  }
};