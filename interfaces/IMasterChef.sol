// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMasterChef {
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. JOE to distribute per block.
        uint256 lastRewardTimestamp; // Last block number that JOE distribution occurs.
        uint256 accJoePerShare; // Accumulated JOE per share, times 1e12. See below.
    }

    function poolInfo(uint256 pid)
        external
        view
        returns (IMasterChef.PoolInfo memory);

    function poolLength() external view returns (uint256 pools);

    function totalAllocPoint() external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function pendingTokens(uint256 pid, address user)
        external
        view
        returns (uint256);
}
