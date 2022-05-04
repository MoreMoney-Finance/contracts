// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "../roles/RoleAware.sol";
import "../roles/DependsOnStableCoin.sol";

contract iMoney is ERC20, ERC20Permit, RoleAware, DependsOnStableCoin {
    struct Account {
        uint256 depositAmount;
        uint256 lastCumulReward;
    }

    mapping(address => Account) public accounts;
    uint256 public cumulRewardPer1e18 = 1;

    constructor(address roles)
        RoleAware(roles)
        ERC20("iMoney", "iMoney")
        ERC20Permit("iMoney")
    {
        _rolesPlayed.push(MINTER_BURNER);
    }

    /// Locks MONEY and mints iMoney
    function deposit(uint256 _amount) public {
        updateDepositAmount(msg.sender);

        stableCoin().burn(msg.sender, _amount);
        _mint(msg.sender, _amount);
    }

    /// Unlocks the staked + gained MONEY and burns iMoney
    function withdraw(uint256 _amount) public {
        updateDepositAmount(msg.sender);

        _burn(msg.sender, _amount);
        stableCoin().mint(msg.sender, _amount);
    }

    /// Register any incoming reward to an account
    function updateDepositAmount(address user) internal {
        registerReward();
        Account storage account = accounts[user];

        if (account.lastCumulReward > 0) {
            uint256 reward = (account.depositAmount *
                (cumulRewardPer1e18 - account.lastCumulReward)) / 1e18;

            _mint(user, reward);
            account.depositAmount += reward;
        }

        account.lastCumulReward = cumulRewardPer1e18;
    }

    /// Register any incoming reward to the entire system
    function registerReward() public {
        if (totalSupply() > 0) {
            Stablecoin stable = stableCoin();

            uint256 incoming = stable.balanceOf(address(this));
            if (incoming > 0) {
                stable.burn(address(this), incoming);
                cumulRewardPer1e18 += (1e18 * incoming) / totalSupply();
            }
        }
    }
}
