// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../roles/RoleAware.sol";

/// Redistribute masterchef (and other) rewards to stakers
contract LyRedistributor is RoleAware {
    using SafeERC20 for IERC20;

    struct RewardToken {
        address token;
        uint256 cumulRewardPer1e18;
        uint256 reserve;
    }

    IERC20 public immutable stakeToken;

    RewardToken[] public rewardTokens;
    mapping(address => uint256) public stakedBalance;
    mapping(address => mapping(uint256 => uint256)) public rewardIndex;

    constructor(
        address _stakeToken,
        address[] memory _rewardTokens,
        address _roles
    ) RoleAware(_roles) {
        for (uint256 i; _rewardTokens.length > i; i++) {
            rewardTokens.push(
                RewardToken({
                    token: _rewardTokens[i],
                    cumulRewardPer1e18: 0,
                    reserve: 0
                })
            );
        }
        stakeToken = IERC20(_stakeToken);
    }

    /// Deposit yield bearing tokens
    function stake(uint256 amount) external {
        if (amount > 0) {
            stakeToken.safeTransferFrom(msg.sender, address(this), amount);
        }

        disburseReward(msg.sender);
        stakedBalance[msg.sender] += amount;
    }

    /// Withdraw yield bearing tokens
    function unstake(uint256 amount, address recipient) external {
        disburseReward(msg.sender);
        stakedBalance[msg.sender] -= amount;
        if (amount > 0) {
            stakeToken.safeTransfer(recipient, amount);
        }
    }

    /// Claim yield for account without depositing or withdrawing
    function harvest() external {
        disburseReward(msg.sender);
    }

    /// Send the accrued reward to the staker
    function disburseReward(address user) internal {
        uint256 userStake = stakedBalance[user];
        updateRewardTotal();

        mapping(uint256 => uint256) storage idxes = rewardIndex[user];
        for (uint256 i; rewardTokens.length > i; i++) {
            RewardToken storage r = rewardTokens[i];

            uint256 idx = idxes[i];
            if (r.cumulRewardPer1e18 > idx && userStake > 0) {
                IERC20(r.token).safeTransfer(
                    user,
                    (userStake * (r.cumulRewardPer1e18 - idx)) / 1e18
                );
            }

            // if the user hasn't any yield yet,
            // this initializes them without back yield
            idxes[i] = r.cumulRewardPer1e18;
        }

        // important to update reserves after sending reward to users
        updateRewardTotal();
    }

    /// Account for any incoming rewards, to be distributed,
    /// as well as reward outflows in reserve
    function updateRewardTotal() public {
        uint256 totalStaked = stakeToken.balanceOf(address(this));
        for (uint256 i; rewardTokens.length > i; i++) {
            RewardToken storage r = rewardTokens[i];
            IERC20 token = IERC20(r.token);
            uint256 balance = token.balanceOf(address(this));
            if (balance > r.reserve) {
                r.cumulRewardPer1e18 +=
                    (1e18 * (balance - r.reserve)) /
                    totalStaked;
            }
            r.reserve = balance;
        }
    }

    function addRewardToken(address token) external onlyOwnerExec {
        rewardTokens.push(
            RewardToken({token: token, cumulRewardPer1e18: 0, reserve: 0})
        );
    }

    /// Rescue stranded funds
    function rescueFunds(
        address token,
        address recipient,
        uint256 amount
    ) external onlyOwnerExec {
        IERC20(token).safeTransfer(recipient, amount);
    }
}
