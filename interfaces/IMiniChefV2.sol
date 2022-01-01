// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMiniChefV2 {
    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of reward entitled to the user.
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of reward to distribute per block.
    struct PoolInfo {
        uint128 accRewardPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    function poolInfo(uint256 pid) external view returns (PoolInfo memory);

    function lpToken(uint256 pid) external view returns (address);

    function poolLength() external view returns (uint256 pools);

    function deposit(
        uint256 _pid,
        uint256 _amount,
        address to
    ) external;

    function withdrawAndHarvest(
        uint256 _pid,
        uint256 _amount,
        address to
    ) external;

    /// @notice Harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of rewards.
    function harvest(uint256 pid, address to) external;

    function pendingReward(uint256 pid, address user)
        external
        view
        returns (uint256);

    function rewardPerSecond() external view returns (uint256);

    function totalAllocPoint() external view returns (uint256);
}
