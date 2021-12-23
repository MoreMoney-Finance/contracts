// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./YieldConversionStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IMiniChefV2.sol";

/// Self-repaying strategy using MasterChef rewards
contract MiniChefStrategy is YieldConversionStrategy {
    using SafeERC20 for IERC20;

    IMiniChefV2 public immutable chef;
    mapping(address => uint256) internal pids;

    constructor(
        bytes32 stratName,
        address _chef,
        address _rewardToken,
        address _roles
    )
        Strategy(stratName)
        YieldConversionStrategy(_rewardToken)
        TrancheIDAware(_roles)
    {
        chef = IMiniChefV2(_chef);
    }

    /// We encode PIDs in such a way so that an unset PID throws an eror
    function viewPid(address token) public view returns (uint256) {
        return pids[token] - 1;
    }

    /// send tokens to masterchef
    function collectCollateral(
        address source,
        address ammPair,
        uint256 collateralAmount
    ) internal override {
        IERC20(ammPair).safeTransferFrom(
            source,
            address(this),
            collateralAmount
        );
        IERC20(ammPair).safeIncreaseAllowance(address(chef), collateralAmount);
        chef.deposit(viewPid(ammPair), collateralAmount, address(this));
        tallyReward(ammPair);
    }

    /// withdraw back to user
    function returnCollateral(
        address recipient,
        address ammPair,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        require(recipient != address(0), "Don't send to zero address");

        uint256 balanceBefore = IERC20(ammPair).balanceOf(address(this));
        chef.withdrawAndHarvest(
            viewPid(ammPair),
            collateralAmount,
            address(this)
        );
        uint256 balanceDelta = IERC20(ammPair).balanceOf(address(this)) -
            balanceBefore;
        tallyReward(ammPair);
        IERC20(ammPair).safeTransfer(recipient, balanceDelta);

        return balanceDelta;
    }

    /// Internal, initialize a token
    function _approveToken(address token, bytes calldata data)
        internal
        override
    {
        uint256 pid = abi.decode(data, (uint256));
        require(
            address(chef.lpToken(pid)) == token,
            "Provided PID does not correspond to MiniChef"
        );
        pids[token] = pid + 1;

        super._approveToken(token, data);
    }

    /// Initialization, encoding args
    function checkApprovedAndEncode(address token, uint256 pid)
        public
        view
        returns (bool, bytes memory)
    {
        return (
            approvedToken(token) && pids[token] == pid + 1,
            abi.encode(pid)
        );
    }

    /// Harvest from Masterchef
    function harvestPartially(address token) external override nonReentrant {
        uint256 pid = viewPid(token);
        chef.harvest(pid, address(this));
        tallyReward(token);
    }

    /// View pending reward
    function viewSourceHarvestable(address token)
        public
        view
        override
        returns (uint256)
    {
        uint256 pid = viewPid(token);
        return
            _viewValue(
                address(rewardToken),
                chef.pendingReward(pid, address(this)),
                yieldCurrency()
            );
    }
}
