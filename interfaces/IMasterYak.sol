// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IMasterYak {
    function add(
        uint256 allocPoint,
        address token,
        bool withUpdate,
        bool vpForDeposit
    ) external;

    function addRewardsBalance() external;

    function changeOwner(address newOwner) external;

    function deposit(uint256 pid, uint256 amount) external;

    function depositWithPermit(
        uint256 pid,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function emergencyWithdraw(uint256 pid) external;

    function endTimestamp() external view returns (uint256);

    function getMultiplier(uint256 from, uint256 to)
        external
        view
        returns (uint256);

    function lockManager() external view returns (address);

    function massUpdatePools() external;

    function owner() external view returns (address);

    function pendingRewards(uint256 pid, address account)
        external
        view
        returns (uint256);

    function poolInfo(uint256)
        external
        view
        returns (
            address token,
            uint256 allocPoint,
            uint256 lastRewardTimestamp,
            uint256 accRewardsPerShare,
            uint256 totalStaked,
            bool vpForDeposit
        );

    function poolLength() external view returns (uint256);

    function rewardsActive() external view returns (bool);

    function rewardsPerSecond() external view returns (uint256);

    function set(
        uint256 pid,
        uint256 allocPoint,
        bool withUpdate
    ) external;

    function setLockManager(address newAddress) external;

    function setRewardsPerSecond(uint256 newRewardsPerSecond) external;

    function startTimestamp() external view returns (uint256);

    function totalAllocPoint() external view returns (uint256);

    function updatePool(uint256 pid) external;

    function userInfo(uint256, address)
        external
        view
        returns (uint256 amount, uint256 rewardTokenDebt);

    function withdraw(uint256 pid, uint256 amount) external;
}
