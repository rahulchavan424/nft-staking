// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RewardToken is ERC20 {
    constructor() ERC20("Token", "TKN") {}

    function mint(address user, uint256 amount) public {
        _mint(user, amount);
    }
}