# Use the following commands to ease the work.

### change default network in ```hardhat.config.js``` to your preferred network to deploy on that network

#### to compile contract use
```shell
npx hardhat compile
```

#### to deploy contract use (for polygon amoy)
```shell
npx hardhat run --network polygonAmoy scripts/Deploy/NFTStaking.js 
```

#### to upgrade contract use (for polygon amoy)
```shell
npx hardhat run --network polygonAmoy scripts/Upgrade/NFTStaking.js
```

## For more details about contracts use

```shell
npx hardhat docgen
```

### then open the `index.html` in `docs` folder in your browser and gather all the details required

#### deployed contract on polygon amoy

```shell
NFTStaking: https://amoy.polygonscan.com/address/0x975A473E9E7b71B390A6A05811bd54B8573aBa3a
```

#### dummy nft and token rewrad contracts used

```shell
NFTContract: https://amoy.polygonscan.com/address/0x99c340909a7907ee8433b73ed42c3124f4edea9b
RewardToken: https://amoy.polygonscan.com/address/0x90b584cf36a8798b4e70311c351d898027deee94
```