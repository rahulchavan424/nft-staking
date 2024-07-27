const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("NFTStaking", function () {
  let NFTStaking, nftStaking, owner, addr1, addr2;
  let MockNFT, mockNFT;
  let MockERC20, mockERC20;

  const REWARD_PER_BLOCK = ethers.utils.parseEther("0.1");
  const UNBONDING_PERIOD = 86400; // 1 day in seconds
  const REWARD_CLAIM_DELAY = 3600; // 1 hour in seconds

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy mock NFT contract
    MockNFT = await ethers.getContractFactory("NFTContract");
    mockNFT = await MockNFT.deploy();
    await mockNFT.deployed();

    // Deploy mock ERC20 contract
    MockERC20 = await ethers.getContractFactory("RewardToken");
    mockERC20 = await MockERC20.deploy();
    await mockERC20.deployed();

    // Deploy NFTStaking contract
    NFTStaking = await ethers.getContractFactory("NFTStaking");
    nftStaking = await upgrades.deployProxy(NFTStaking, [
      mockNFT.address,
      mockERC20.address,
      REWARD_PER_BLOCK,
      UNBONDING_PERIOD,
      REWARD_CLAIM_DELAY
    ]);
    await nftStaking.deployed();

    // Mint some NFTs to addr1
    await mockNFT.connect(addr1).mint(addr1.address, 1);
    await mockNFT.connect(addr1).mint(addr1.address, 2);

    // Mint some reward tokens to the staking contract
    await mockERC20.mint(nftStaking.address, ethers.utils.parseEther("1000"));

    // Approve NFTStaking contract to transfer NFTs
    await mockNFT.connect(addr1).setApprovalForAll(nftStaking.address, true);
  });

  describe("Staking", function () {
    it("Should allow staking NFTs", async function () {
      await expect(nftStaking.connect(addr1).stakeNFT([1]))
        .to.emit(nftStaking, "NFTStaked")
        .withArgs(addr1.address, 1, await ethers.provider.getBlock("latest").then(b => b.timestamp));

      expect(await nftStaking.getTotalStakedNFTs()).to.equal(1);
    });

    it("Should not allow staking NFTs that are not owned", async function () {
      await expect(nftStaking.connect(addr2).stakeNFT([1])).to.be.revertedWith("Invalid nft id");
    });
  });

  describe("Unstaking", function () {
    beforeEach(async function () {
      await nftStaking.connect(addr1).stakeNFT([1]);
    });

    it("Should allow starting unstaking process", async function () {
      await expect(nftStaking.connect(addr1).startUnstaking([0]))
        .to.emit(nftStaking, "NFTUnbondingStarted")
        .withArgs(addr1.address, 1, await ethers.provider.getBlock("latest").then(b => b.timestamp));
    });

    it("Should not allow withdrawing before unbonding period", async function () {
      await nftStaking.connect(addr1).startUnstaking([0]);
      await expect(nftStaking.connect(addr1).withdrawNFT([0])).to.be.revertedWith("Invalid stake if or nft unstaked");
    });

    it("Should allow withdrawing after unbonding period", async function () {
      await nftStaking.connect(addr1).startUnstaking([0]);
      await ethers.provider.send("evm_increaseTime", [UNBONDING_PERIOD]);
      await ethers.provider.send("evm_mine");

      await expect(nftStaking.connect(addr1).withdrawNFT([0]))
        .to.emit(nftStaking, "NFTWithdrawn")
        .withArgs(addr1.address, 1, await ethers.provider.getBlock("latest").then(b => b.timestamp));

      expect(await nftStaking.getTotalStakedNFTs()).to.equal(0);
    });
  });

  describe("Rewards", function () {
    beforeEach(async function () {
      await nftStaking.connect(addr1).stakeNFT([1]);
    });

    it("Should accumulate rewards", async function () {
      await ethers.provider.send("evm_increaseTime", [3600]);
      await ethers.provider.send("evm_mine");

      const rewards = await nftStaking.calculateRewards(addr1.address);
      expect(rewards).to.be.gt(0);
    });

    it("Should allow claiming rewards after delay", async function () {
      await ethers.provider.send("evm_increaseTime", [REWARD_CLAIM_DELAY]);
      await ethers.provider.send("evm_mine");

      await expect(nftStaking.connect(addr1).claimRewards())
        .to.emit(nftStaking, "RewardsClaimed")
        .withArgs(addr1.address, await nftStaking.calculateRewards(addr1.address));
    });

    it("Should not allow claiming rewards before delay", async function () {
      await expect(nftStaking.connect(addr1).claimRewards()).to.be.revertedWith("Cannot claim yet");
    });
  });

  describe("Admin functions", function () {
    it("Should allow owner to update reward per block", async function () {
      const newReward = ethers.utils.parseEther("0.2");
      await expect(nftStaking.setRewardPerBlock(newReward))
        .to.emit(nftStaking, "RewardPerBlockUpdated")
        .withArgs(REWARD_PER_BLOCK, newReward);
    });

    it("Should allow owner to update unbonding period", async function () {
      const newPeriod = 172800; // 2 days
      await expect(nftStaking.setUnbondingPeriod(newPeriod))
        .to.emit(nftStaking, "UnbondingPeriodUpdated")
        .withArgs(UNBONDING_PERIOD, newPeriod);
    });

    it("Should allow owner to update reward claim delay", async function () {
      const newDelay = 7200; // 2 hours
      await expect(nftStaking.setRewardClaimDelay(newDelay))
        .to.emit(nftStaking, "RewardClaimDelayUpdated")
        .withArgs(REWARD_CLAIM_DELAY, newDelay);
    });
  });
});