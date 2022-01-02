// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../strategies/YieldConversionStrategy.sol";

contract TestRepayingStrategy is YieldConversionStrategy {
    using SafeERC20 for IERC20;

    constructor(address _rewardToken, address _roles)
        Strategy("Test repaying strategy")
        YieldConversionStrategy(_rewardToken)
        TrancheIDAware(_roles)
    {}

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
        tallyReward(ammPair);
    }

    /// withdraw back to user
    function returnCollateral(
        address recipient,
        address ammPair,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        require(recipient != address(0), "Don't send to zero address");
        IERC20(ammPair).safeTransfer(recipient, collateralAmount);

        return collateralAmount;
    }

    /// Harvest from Masterchef
    function harvestPartially(address token) external override nonReentrant {
        IERC20(rewardToken).safeTransferFrom(owner(), address(this), 1000000);
        tallyReward(token);
    }

    /// View pending reward
    function viewSourceHarvestable(address)
        public
        pure
        override
        returns (uint256)
    {
        return 1000000;
    }

    // View the underlying yield strategy (if any)
    function viewUnderlyingStrategy(address)
        public
        view
        virtual
        override
        returns (address)
    {
        return address(this);
    }

    /// Initialize token
    function checkApprovedAndEncode(address token)
        public
        view
        returns (bool, bytes memory)
    {
        return (approvedToken(token), "");
    }
}
