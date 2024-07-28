// deploy command : npx hardhat run --network polygonAmoy scripts/Deploy/NFTStaking.js
// npx hardhat verify --network polygonAmoy <contract-address>

async function deployNFTStaking() {
  let hre = require("hardhat");
  let fs = require("fs");
  let deployContract = "NFTStaking";
  let deployedContract = require("../../Deployments/" +
    deployContract +
    ".json");
  const network = await hre.network.name;
  console.log(network);
  deployContract[network] = {};

  console.log("previous Deployment: ", deployedContract);

  const feeData = await hre.ethers.provider.getFeeData();
  console.log(feeData);

  const NFTStaking = await hre.ethers.getContractFactory("NFTStaking");
  const NFTStakingProxy = await hre.upgrades.deployProxy(
    NFTStaking,
    [
      "0x99C340909a7907EE8433b73ED42C3124f4EdEA9B",
      "0x90b584CF36a8798b4e70311c351D898027deee94",
      "100000000000000",
      "600",
      "600",
    ],
    {
      initializer: "initialize",
      kind: "uups",
      maxFeePerGas : 10000000000, // 50 gwei
      maxPriorityFeePerGas : 10000000000 //50 gwei
    }
  );
  await NFTStakingProxy.deployed();

  console.log("New : ", {
    NFTStakingAddress: NFTStakingProxy.address,
  });

  deployedContract[network] = {
    NFTStakingAddress: NFTStakingProxy.address,
  };

  fs.writeFileSync(
    "./Deployments/" + deployContract + ".json",
    JSON.stringify(deployedContract)
  );
}

deployNFTStaking()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
