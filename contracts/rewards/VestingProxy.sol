// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./VestingStakingRewards.sol";

contract VestingProxy is Ownable {
    using SafeERC20 for IERC20;

    address immutable user;

    uint256 cachedTotal;

    uint256 allRewardEver;
    uint256 allRewardDisbursed;

    uint256 rewardLastUpdated;

    uint256 vestingPeriod = 60 days;

    VestingStakingRewards public immutable vestingRewards;
    IERC20 public immutable rewardToken;
    IERC20 public immutable stakingToken;

    constructor(address _user, address _vestingRewards, address _rewardToken, address _stakingToken) {
        rewardLastUpdated = block.timestamp;

        user = _user;
        vestingRewards = VestingStakingRewards(_vestingRewards);
        rewardToken = IERC20(_rewardToken);
        stakingToken = IERC20(_stakingToken);

        stakingToken.approve(_vestingRewards, type(uint256).max);
    }

    /// Disburse reward and replenish from vesting contract
    function updateReward() public {
        uint256 timeDelta = block.timestamp - rewardLastUpdated;
        if (timeDelta > 0) {
            uint256 outstandingReward = allRewardEver - allRewardDisbursed;
            uint256 rewardAmount = min(
                rewardToken.balanceOf(address(this)),
                min(
                    outstandingReward,
                    outstandingReward * timeDelta / vestingPeriod)
                );
            allRewardDisbursed += rewardAmount;
            rewardToken.safeTransfer(user, rewardAmount);
        }
        rewardLastUpdated = block.timestamp;

        uint256 newTotal = vestingRewards.earned(address(this)) + vestingRewards.rewards(address(this));
        if (newTotal > cachedTotal) {
            uint256 rewardDelta = newTotal - cachedTotal;
            allRewardEver += rewardDelta;
            cachedTotal = newTotal;
        }
    }

    /// This harvest is only necessary if nobody has been interacting with the vesting contract in a while
    /// and supply is getting low 
    function harvest() public {
        updateReward();
        vestingRewards.withdrawVestedReward();
        cachedTotal = vestingRewards.earned(address(this)) + vestingRewards.rewards(address(this));
    }

    function stake(uint256 amount) external {
        require(msg.sender == user, "Only dedicated user");
        updateReward();
        vestingRewards.stake(amount);
        cachedTotal = vestingRewards.earned(address(this)) + vestingRewards.rewards(address(this));
    }

    function withdraw(uint256 amount, address recipient) external {
        require(msg.sender == user, "Only dedicated user");
        updateReward();
        vestingRewards.withdraw(amount);
        cachedTotal = vestingRewards.earned(address(this)) + vestingRewards.rewards(address(this));
        stakingToken.safeTransfer(recipient, amount);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a >= b) {
            return b;
        } else {
            return a;
        }
    }

    /// Rescue stranded funds
    function rescueFunds(
        address token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        IERC20(token).safeTransfer(recipient, amount);
    }

    function setVestingPeriod(uint256 time) external onlyOwner {
        vestingPeriod = time;
    }
}