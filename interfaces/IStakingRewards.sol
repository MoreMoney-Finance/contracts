// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStakingRewards {
    function rewardsToken() external view returns (IERC20);

    function stakingToken() external view returns (IERC20);

    function periodFinish() external returns (uint256);

    function rewardRate() external returns (uint256);

    function rewardsDuration() external returns (uint256);

    function lastUpdateTime() external returns (uint256);

    function rewardPerTokenStored() external returns (uint256);

    function userRewardPerTokenPaid(address user) external returns (uint256);

    function rewards(address user) external returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function lastTimeRewardApplicable() external view returns (uint256);

    function rewardPerToken() external view returns (uint256);

    function earned(address account) external view returns (uint256);

    function getRewardForDuration() external view returns (uint256);

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stakeWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getReward() external;

    function exit() external;
}
