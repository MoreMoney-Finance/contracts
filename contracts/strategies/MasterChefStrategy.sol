// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./YieldConversionStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IMasterChef.sol";

/// Self-repaying strategy using MasterChef rewards
contract MasterChefStrategy is YieldConversionStrategy {
    using SafeERC20 for IERC20;

    IMasterChef public immutable chef;
    mapping(address => uint256) public pids;

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
        chef = IMasterChef(_chef);
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
        IERC20(ammPair).approve(address(chef), collateralAmount);
        chef.deposit(pids[ammPair], collateralAmount);
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
        chef.withdraw(pids[ammPair], collateralAmount);
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
            address(chef.poolInfo(pid).lpToken) == token,
            "Provided PID does not correspond to MasterChef"
        );
        pids[token] = pid;

        super._approveToken(token, data);
    }

    /// Initialization, encoding args
    function checkApprovedAndEncode(address token, uint256 pid)
        public
        view
        returns (bool, bytes memory)
    {
        return (approvedToken(token), abi.encode(pid));
    }

    /// Harvest from Masterchef
    function harvestPartially(address token) external override nonReentrant {
        uint256 pid = pids[token];
        chef.withdraw(pid, 0);
        tallyReward(token);
    }
}
