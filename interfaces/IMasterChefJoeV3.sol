// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMasterChefJoeV3 {
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint256 accJoePerShare;
        uint256 lastRewardTimestamp;
        uint256 allocPoint;
        address rewarder;
    }

    function poolInfo(uint256 pid) external view returns (PoolInfo memory);

    function poolLength() external view returns (uint256 pools);

    function totalAllocPoint() external view returns (uint256);

    function joePerSec() external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function pendingTokens(uint256 pid, address user)
        external
        view
        returns (uint256);
}
