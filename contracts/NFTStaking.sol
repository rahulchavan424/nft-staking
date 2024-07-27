// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title NFTStaking
 * @dev A contract for staking nfts and earning erc20 tokens
 */
contract NFTStaking is PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    // NFT contract
    IERC721Upgradeable public nftContract;
    // ERC20 token contract
    IERC20Upgradeable public rewardToken;

    // Token rewards per block
    uint256 public rewardPerBlock;
    // Period before claiming back nft
    uint256 public unbondingPeriod;
    // Time between reward claims
    uint256 public rewardClaimDelay;

    struct Stake {
        uint256 nftId;
        uint64 timestamp;
        uint64 lastRewardBlock;
        bool isUnbonding;
        uint64 unbondingStartTime;
    }

    struct UserInfo {
        uint256 pendingRewards;
        uint64 lastRewardClaim;
    }

    // Mapping of user address to their staked nfts
    mapping(address => Stake[]) private userStakes;
    // Mapping of nft id to its owner address
    mapping(uint256 => address) private nftOwner;
    // Mapping of user address to stake info
    mapping(address => UserInfo) private userInfo;

    // Total staked nfts
    uint256 public totalStakedNFTs;

    // Events
    event NFTStaked(address user, uint256 nftId, uint256 timestamp);
    event NFTUnstaked(address user, uint256 nftId, uint256 timestamp);
    event NFTUnbondingStarted(address user, uint256 nftId, uint256 timestamp);
    event NFTWithdrawn(address user, uint256 nftId, uint256 timestamp);
    event RewardsClaimed(address user, uint256 amount);
    event RewardPerBlockUpdated(uint256 oldValue, uint256 newValue);
    event UnbondingPeriodUpdated(uint256 oldValue, uint256 newValue);
    event RewardClaimDelayUpdated(uint256 oldValue, uint256 newValue);

    /**
     * @dev Initialize contract
     * @param _nftContract Address of the nft contract
     * @param _rewardToken Address of the reward token contract
     * @param _rewardPerBlock Amount of reward tokens given per block
     * @param _unbondingPeriod Waiting time after unbounding
     * @param _rewardClaimDelay Time between reward claims
     */
    function initialize(
        address _nftContract,
        address _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _unbondingPeriod,
        uint256 _rewardClaimDelay
    ) public initializer {
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        require(_nftContract != address(0) && _rewardToken != address(0), "Invalid address");
        require(_rewardPerBlock > 0, "Invalid reward");
        require(_unbondingPeriod > 0, "Invalid unbonding period");
        require(_rewardClaimDelay > 0, "Invalid claim delay");

        nftContract = IERC721Upgradeable(_nftContract);
        rewardToken = IERC20Upgradeable(_rewardToken);
        rewardPerBlock = _rewardPerBlock;
        unbondingPeriod = _unbondingPeriod;
        rewardClaimDelay = _rewardClaimDelay;
    }

    /**
     * @dev Stake nfts
     * @param _nftIds The ids of the nfts to be staked
     */
    function stakeNFT(uint256[] memory _nftIds) external whenNotPaused nonReentrant {
        uint256 temp;
        for (uint256 i = 0; i < _nftIds.length; i++) {
            if (nftContract.ownerOf(_nftIds[i]) == msg.sender) {
                _updateRewards(msg.sender);

                nftContract.transferFrom(msg.sender, address(this), _nftIds[i]);

                userStakes[msg.sender].push(Stake({
                    nftId: _nftIds[i],
                    timestamp: uint64(block.timestamp),
                    lastRewardBlock: uint64(block.number),
                    isUnbonding: false,
                    unbondingStartTime: 0
                }));

                nftOwner[_nftIds[i]] = msg.sender;
                totalStakedNFTs++;

                emit NFTStaked(msg.sender, _nftIds[i], block.timestamp);
                temp++;
            }
        }

        if (temp == 0) {
            revert("Invalid nft id");
        }
    }

    /**
     * @dev Start unstaking the nfts
     * @param _stakeIds The stake ids of nfts to unstake
     */
    function startUnstaking(uint256[] memory _stakeIds) external whenNotPaused nonReentrant {
        uint256 temp;
        Stake[] storage stakes = userStakes[msg.sender];
        for (uint256 i = 0; i < _stakeIds.length; i++) {
            uint256 _nftId = stakes[_stakeIds[i]].nftId;
            if (nftOwner[_nftId] == msg.sender) {
            
                _updateRewards(msg.sender);

                Stake[] storage stakes = userStakes[msg.sender];
                if (!stakes[_stakeIds[i]].isUnbonding) {
                    stakes[_stakeIds[i]].isUnbonding = true;
                    stakes[_stakeIds[i]].unbondingStartTime = uint64(block.timestamp);
                    emit NFTUnbondingStarted(msg.sender, _nftId, block.timestamp);
                    temp++;
                }
            }
        }

        if (temp == 0) {
            revert("Invalid stake id or nft unbounding");
        }
    }

    /**
     * @dev Withdraw nfts after unstake
     * @param _stakeIds The stake ids of nfts to withdraw
     */
    function withdrawNFT(uint256[] memory _stakeIds) external whenNotPaused nonReentrant {
        uint256 temp;
        Stake[] storage stakes = userStakes[msg.sender];
        for (uint256 i = 0; i < _stakeIds.length; i++) {
            uint256 _nftId = stakes[_stakeIds[i]].nftId;
            if (stakes[_stakeIds[i]].isUnbonding) {
                if (block.timestamp >= stakes[_stakeIds[i]].unbondingStartTime + unbondingPeriod) {
                
                    nftContract.transferFrom(address(this), msg.sender, _nftId);
                    emit NFTWithdrawn(msg.sender, _nftId, block.timestamp);
                    
                    // Remove the stake from the array
                    stakes[_stakeIds[i]] = stakes[stakes.length - 1];
                    stakes.pop();
                    
                    delete nftOwner[_nftId];
                    totalStakedNFTs--;
                    temp++;
                }
            }
        }
        
        if (temp == 0) {
            revert("Invalid stake if or nft unstaked");
        }
    }

    /**
     * @dev Claim token rewards
     */
    function claimRewards() external whenNotPaused nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(block.timestamp >= user.lastRewardClaim + rewardClaimDelay, "Cannot claim yet");

        _updateRewards(msg.sender);

        uint256 rewardsToClaim = user.pendingRewards;
        require(rewardsToClaim > 0, "No claim rewards");

        user.pendingRewards = 0;
        user.lastRewardClaim = uint64(block.timestamp);

        require(rewardToken.transfer(msg.sender, rewardsToClaim), "Claim failed");

        emit RewardsClaimed(msg.sender, rewardsToClaim);
    }

    /**
     * @dev Update user rewards
     * @param _user User address
     */
    function _updateRewards(address _user) internal {
        UserInfo storage user = userInfo[_user];
        uint256 newRewards = calculateRewards(_user);
        user.pendingRewards += newRewards;

        Stake[] storage stakes = userStakes[_user];
        for (uint256 i = 0; i < stakes.length; i++) {
            if (!stakes[i].isUnbonding) {
                stakes[i].lastRewardBlock = uint64(block.number);
            }
        }
    }

    /**
     * @dev Calculate reward for a user
     * @param _user User address
     * @return Total amount of rewards
     */
    function calculateRewards(address _user) public view returns (uint256) {
        uint256 totalRewards = 0;
        Stake[] memory stakes = userStakes[_user];

        for (uint256 i = 0; i < stakes.length; i++) {
            if (!stakes[i].isUnbonding) {
                uint256 blocksElapsed = block.number - stakes[i].lastRewardBlock;
                totalRewards += blocksElapsed * rewardPerBlock;
            }
        }

        return totalRewards;
    }

    /**
     * @dev Pauses the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Updates the reward
     * @param _newRewardPerBlock New reward amount
     */
    function setRewardPerBlock(uint256 _newRewardPerBlock) external onlyOwner {
        require(_newRewardPerBlock > 0, "Invalid reward per block");
        uint256 oldRewardPerBlock = rewardPerBlock;
        rewardPerBlock = _newRewardPerBlock;
        emit RewardPerBlockUpdated(oldRewardPerBlock, _newRewardPerBlock);
    }

    /**
     * @dev Updates the unbonding time
     * @param _newUnbondingPeriod New unbonding time
     */
    function setUnbondingPeriod(uint256 _newUnbondingPeriod) external onlyOwner {
        require(_newUnbondingPeriod > 0, "Invalid unbonding period");
        uint256 oldUnbondingPeriod = unbondingPeriod;
        unbondingPeriod = _newUnbondingPeriod;
        emit UnbondingPeriodUpdated(oldUnbondingPeriod, _newUnbondingPeriod);
    }

    /**
     * @dev Updates the claim delay
     * @param _newRewardClaimDelay New claim delay
     */
    function setRewardClaimDelay(uint256 _newRewardClaimDelay) external onlyOwner {
        require(_newRewardClaimDelay > 0, "Invalid reward claim delay");
        uint256 oldRewardClaimDelay = rewardClaimDelay;
        rewardClaimDelay = _newRewardClaimDelay;
        emit RewardClaimDelayUpdated(oldRewardClaimDelay, _newRewardClaimDelay);
    }

    /**
     * @dev Returns all stakes of user
     * @param _user User address
     * @return Array of stakes
     */
    function getUserStakes(address _user) external view returns (Stake[] memory) {
        return userStakes[_user];
    }

    /**
     * @dev Returns user info
     * @param _user Address of the user
     * @return Userinfo struct
     */
    function getUserInfo(address _user) external view returns (UserInfo memory) {
        return userInfo[_user];
    }

    /**
     * @dev Returns total nfts staked
     * @return Total staked nfts
     */
    function getTotalStakedNFTs() external view returns (uint256) {
        return totalStakedNFTs;
    }

    /**
     * @dev Function to upgrade contract
     * @param newImplementation New impl address
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}