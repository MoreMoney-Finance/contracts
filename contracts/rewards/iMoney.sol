// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "../roles/RoleAware.sol";
import "../roles/DependsOnStableCoin.sol";
import "../../interfaces/IListener.sol";

contract iMoney is
    ERC20,
    ERC20Permit,
    RoleAware,
    DependsOnStableCoin,
    IListener
{
    struct Account {
        uint256 depositAmount;
        uint256 lastCumulRewardSimple;
        uint256 lastCumulRewardWeighted;
        uint256 factor;
    }

    mapping(address => Account) public accounts;
    uint256 public cumulRewardPer1e18Simple = 1;
    uint256 public cumulRewardPer1e18Weighted = 1;
    uint256 public totalWeights;
    address immutable vemore;

    uint256 public boostedSharePer10k = 5000;

    constructor(address _vemore, address roles)
        RoleAware(roles)
        ERC20("iMoney", "iMoney")
        ERC20Permit("iMoney")
    {
        _rolesPlayed.push(MINTER_BURNER);
        vemore = _vemore;
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

        uint256 weight = sqrt(account.factor * account.depositAmount);

        uint256 reward = calcPendingReward(account, 0);

        account.depositAmount += reward;
        _mint(user, reward);
        totalWeights =
            totalWeights +
            sqrt(account.depositAmount * account.factor) -
            weight;

        account.lastCumulRewardSimple = cumulRewardPer1e18Simple;
        account.lastCumulRewardWeighted = cumulRewardPer1e18Weighted;
    }

    /// Register any incoming reward to the entire system
    function registerReward() public {
        if (totalSupply() > 0) {
            Stablecoin stable = stableCoin();
            uint256 incoming = stable.balanceOf(address(this));
            if (incoming > 0) {
                stable.burn(address(this), incoming);

                (
                    cumulRewardPer1e18Simple,
                    cumulRewardPer1e18Weighted
                ) = viewUpdatedCumulRewards(incoming);
            }
        }
    }

    /// Update the boosting factor for an account
    function updateFactor(address user, uint256 veBalance) external override {
        require(msg.sender == vemore, "Not autorized to update factor");
        updateDepositAmount(user);
        Account storage account = accounts[user];
        totalWeights =
            totalWeights +
            sqrt(account.depositAmount * veBalance) -
            sqrt(account.depositAmount * account.factor);
        account.factor = veBalance;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /// Set the share of rewards that is distributed according to boosted weights
    function setBoostedSharePer10k(uint256 newBoostedShare)
        external
        onlyOwnerExec
    {
        require(10_000 >= newBoostedShare, "Boosted share out of bounds");
        boostedSharePer10k = newBoostedShare;
    }

    /// Calculate pending reward for an account, including incoming rewards
    function calcPendingReward(Account memory account, uint256 incoming)
        internal
        view
        returns (uint256)
    {
        (
            uint256 _cumulRewardPer1e18Simple,
            uint256 _cumulRewardPer1e18Weighted
        ) = viewUpdatedCumulRewards(incoming);
        uint256 weight = sqrt(account.factor * account.depositAmount);
        uint256 reward;
        if (account.lastCumulRewardWeighted > 0) {
            reward +=
                (weight *
                    (_cumulRewardPer1e18Weighted -
                        account.lastCumulRewardWeighted)) /
                1e18;
        }

        if (account.lastCumulRewardSimple > 0) {
            reward +=
                (account.depositAmount *
                    (_cumulRewardPer1e18Simple -
                        account.lastCumulRewardSimple)) /
                1e18;
        }

        return reward;
    }

    /// Include incoming rewards in cumulative counters
    function viewUpdatedCumulRewards(uint256 incoming)
        public
        view
        returns (
            uint256 _cumulRewardPer1e18Simple,
            uint256 _cumulRewardPer1e18Weighted
        )
    {
        _cumulRewardPer1e18Simple = cumulRewardPer1e18Simple;
        _cumulRewardPer1e18Weighted = cumulRewardPer1e18Weighted;

        if (incoming > 0 && totalSupply() > 0) {
            if (totalWeights > 0) {
                uint256 weightedIncoming = (incoming * boostedSharePer10k) /
                    10_000;
                _cumulRewardPer1e18Weighted +=
                    (1e18 * weightedIncoming) /
                    totalWeights;
                incoming -= weightedIncoming;
            }

            _cumulRewardPer1e18Simple += (1e18 * incoming) / totalSupply();
        }
    }

    /// View pending reward for an account, including incoming reward
    function viewPendingReward(address user, uint256 incoming)
        external
        view
        returns (uint256)
    {
        return
            calcPendingReward(
                accounts[user],
                stableCoin().balanceOf(address(this)) + incoming
            );
    }
}
