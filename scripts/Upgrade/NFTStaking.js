// This will upgrade the contract to same proxy address.
// deploy command : npx hardhat run --network polygon_amoy scripts/Upgrade/NFTStaking.js

async function upgradeNFTStaking() {

    let hre = require("hardhat");
    let fs = require("fs");
    let deployContract = "NFTStaking";
    let deployedContract = require("../../Deployments/" + deployContract + ".json");
    const network = await hre.network.name;

    console.log("previous Deployment: ", deployedContract);

    const NFTStaking = await hre.ethers.getContractFactory("NFTStaking");
    const NFTStakingProxy = await hre.upgrades.upgradeProxy(deployedContract[network].NFTStakingAddress, NFTStaking);
    // deployedContract[network] = {};

    console.log("New : ", {
        NFTStakingAddress: NFTStakingProxy.address,
    });

    deployedContract[network] = {
        NFTStakingAddress: NFTStakingProxy.address,
    };

    fs.writeFileSync("./Deployments/" + deployContract + ".json", JSON.stringify(deployedContract));

}

upgradeNFTStaking()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });