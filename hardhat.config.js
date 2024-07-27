require('dotenv').config();
require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require('hardhat-docgen');

module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {},
        polygon: {
            url: "https://polygon-mainnet.g.alchemy.com/v2/zoNm-CgB1rQIn0DG1XG0hRHV0hgFW71X",
            accounts: [process.env.PRIVATE_KEY]
        },
        polygonAmoy: {
            url: "https://polygon-amoy.g.alchemy.com/v2/zoNm-CgB1rQIn0DG1XG0hRHV0hgFW71X",
            accounts: [process.env.PRIVATE_KEY]
        },
    },
    etherscan: {
        apiKey: {
            polygonAmoy: process.env.POLYGONSCAN_API_KEY,
        },
        customChains: [
            {
                network: "polygonAmoy",
                chainId: 80002,
                urls: {
                    apiURL: "https://api-amoy.polygonscan.com/api",
                    browserURL: "https://amoy.polygonscan.com/",
                },
            },
        ], // apiKey: "PSI67I4T9C9U9C7831AJE2RKE8R9H9ED7I",
    }, solidity: {
        version: "0.8.20", settings: {
            optimizer: {
                enabled: true, runs: 200
            },
        }
    },
    // docgen: {
    //   path: './docs',
    //   clear: true,
    //   runOnCompile: true,
    // },
}