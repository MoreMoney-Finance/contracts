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
    ) internal override {
        address stakingContract = stakingContracts[token];
        IStakingRewards(stakingContract).getReward();
        tallyReward(token);

        IERC20(token).safeTransferFrom(source, address(this), collateralAmount);
        IERC20(token).safeIncreaseAllowance(stakingContract, collateralAmount);

        IStakingRewards(stakingContract).stake(collateralAmount);
    }

    /// Withdraw from stakoing
    function returnCollateral(
        address recipient,
        address token,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        require(recipient != address(0), "Don't send to zero address");

        IStakingRewards stakingContract = IStakingRewards(
            stakingContracts[token]
        );

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        stakingContract.withdraw(collateralAmount);
        uint256 balanceDelta = IERC20(token).balanceOf(address(this)) -
            balanceBefore;

        IERC20(token).safeTransfer(recipient, balanceDelta);
        stakingContract.getReward();
        tallyReward(token);

        return balanceDelta;
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
    function harvestPartially(address token) external override nonReentrant {
        IStakingRewards(stakingContracts[token]).getReward();
        tallyReward(token);
    }

    /// View pending reward
    function viewSourceHarvestable(address token)
        public
        view
        override
        returns (uint256)
    {
        return
            _viewValue(
                address(rewardToken),
                IStakingRewards(stakingContracts[token]).earned(address(this)),
                yieldCurrency()
            );
    }


    // View the underlying yield strategy (if any)
    function viewUnderlyingStrategy(address token)
        public
        virtual
        override
        view
        returns (address) {
            return stakingContracts[token];
        }
}
