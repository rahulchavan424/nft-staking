// deploy command : npx hardhat run --network polygon_amoy scripts/Deploy/NFTStaking.js
// npx hardhat verify --network polygon_amoy <contract-address>

async function deployNFTStaking() {

    let hre = require("hardhat");
    let fs = require("fs");
    let deployContract = "NFTStaking";
    let deployedContract = require("../../Deployments/" + deployContract + ".json");
    const network = await hre.network.name;
    deployContract[network] = {};

    console.log("previous Deployment: ", deployedContract);

    const NFTStaking = await hre.ethers.getContractFactory("NFTStaking");
    const NFTStakingProxy = await hre.upgrades.deployProxy(NFTStaking, [], {
        initializer: "Initialize",
        kind: "uups",
    });
    await NFTStakingProxy.deployed();

    console.log("New : ", {
        NFTStakingAddress: NFTStakingProxy.address,
    });

    deployedContract[network] = {
        NFTStakingAddress: NFTStakingProxy.address,
    };

    fs.writeFileSync("./Deployments/" + deployContract + ".json", JSON.stringify(deployedContract));

}

deployNFTStaking()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });