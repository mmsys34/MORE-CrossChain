require("@nomicfoundation/hardhat-foundry");
require("@nomicfoundation/hardhat-verify");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();
require("./tasks");

module.exports = {
  solidity: {
    compilers: [  
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      }
    ]
  },
  networks: {
    hardhat: {
      forking: {
        enabled: true,
        url: process.env.FLOW_RPC_URL,
        chainId: 747,
      },
    },
    flowTestnet: {
      url: process.env.FLOW_TESTNET_RPC_URL,
      chainId: 545,
      accounts: [process.env.PRIVATE_KEY]
    },
    flow: {
      url: process.env.FLOW_RPC_URL,
      chainId: 747,
      accounts: [process.env.PRIVATE_KEY]
    },
    mainnet: {
      url: process.env.ETH_RPC_URL,
      chainId: 1,
      accounts: [process.env.PRIVATE_KEY]
    },
    arbitrum: {
      url: process.env.ARB_RPC_URL,
      chainId: 42161,
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETH_API_KEY,
      arbitrum: process.env.ARB_API_KEY,
      flow: "abc",
      flowTestnet: "abc"
    },
    customChains: [
      {
        network: "flowTestnet",
        chainId: 545,
        urls: {
          apiURL: "https://evm-testnet.flowscan.io/api",
          browserURL: "https://evm-testnet.flowscan.io/",
        }
      },
      {
        network: "flow",
        chainId: 747,
        urls: {
          apiURL: "https://evm.flowscan.io/api",
          browserURL: "https://evm.flowscan.io/",
        }
      }
    ]
  }
}
