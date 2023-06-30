require("@nomicfoundation/hardhat-toolbox");

require('dotenv').config();


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.10",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
    },
    polygon_mumbai: {
      url: "https://polygon-mumbai.g.alchemy.com/v2/LRVzMsQ6HDscvzkEcuXY_isfi0o_vs6x",
      accounts: [process.env.PRIVATE_KEY]
    }
  },
};