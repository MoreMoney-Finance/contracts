// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./YieldConversionStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IStakingRewards.sol";

/// Strategy for synthetix-style reward staking
contract StakingRewardsStrategy is YieldConversionStrategy {
    using SafeERC20 for IERC20;

    mapping(address => address) public stakingContracts;

    constructor(
        bytes32 stratName,
        address _rewardToken,
        address _roles
    )
        Strategy(stratName)
        YieldConversionStrategy(_rewardToken)
        TrancheIDAware(_roles)
    {}

    /// send collateral to staking
    function collectCollateral(
        address source,
        address token,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        IERC20(token).safeTransferFrom(source, address(this), collateralAmount);

        address stakingContract = stakingContracts[token];
        IERC20(token).approve(stakingContract, collateralAmount);

        IStakingRewards(stakingContract).stake(collateralAmount);
        IStakingRewards(stakingContract).getReward();
        tallyReward(token);

        return collateralAmount;
    }

    /// Withdraw from stakoing
    function returnCollateral(
        address recipient,
        address token,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        IStakingRewards stakingContract = IStakingRewards(
            stakingContracts[token]
        );
        stakingContract.withdraw(collateralAmount);
        IERC20(token).safeTransfer(recipient, collateralAmount);
        stakingContract.getReward();
        tallyReward(token);

        return collateralAmount;
    }

    /// Initialize token
    function _approveToken(address token, bytes calldata data)
        internal
        override
    {
        address stakingContractAddress = abi.decode(data, (address));
        IStakingRewards stakingContract = IStakingRewards(
            stakingContractAddress
        );

        IERC20 _rewardToken = stakingContract.rewardsToken();
        IERC20 _stakingToken = stakingContract.stakingToken();

        require(
            address(_stakingToken) == token,
            "Staking token does not match"
        );
        require(_rewardToken == rewardToken, "Reward token does not match");

        stakingContracts[token] = stakingContractAddress;

        super._approveToken(token, data);
    }

    /// For initialization purposes
    function checkApprovedAndEncode(address token, address stakingContract)
        public
        view
        returns (bool, bytes memory)
    {
        return (approvedToken(token), abi.encode(stakingContract));
    }

    /// Harvest from reward contract
    function harvestPartially(address token) public override {
        IStakingRewards(stakingContracts[token]).getReward();
        tallyReward(token);
    }
}
