// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./MintFromLiqToken.sol";
import "./MintFromStrategy.sol";
import "../interfaces/IYakStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// Use staking on YieldYak as yield strategy
contract MintFromYieldYakLiqToken is MintFromStrategy {
    using SafeERC20 for IERC20;
    IYakStrategy public immutable yakStrategy;

    constructor(
        address _ammPair,
        address _oracleForToken0,
        address _oracleForToken1,
        uint256 _reservePermil,
        address _yakStrategy,
        address _rewardToken,
        uint256 _conversionBidWindow,
        address _roles
    )
        MintFromStrategy(
            _ammPair,
            _oracleForToken0,
            _oracleForToken1,
            _reservePermil,
            _rewardToken,
            _conversionBidWindow,
            _roles
        )
    {
        yakStrategy = IYakStrategy(_yakStrategy);
    }

    function collectCollateral(address source, uint256 collateralAmount)
        internal
        override
    {
        IERC20(address(ammPair)).safeTransferFrom(
            source,
            address(this),
            collateralAmount
        );
        ammPair.approve(address(yakStrategy), collateralAmount);
        uint256 balanceBefore = IERC20(address(yakStrategy)).balanceOf(
            address(this)
        );
        yakStrategy.deposit(collateralAmount);
        uint256 balanceAfter = IERC20(address(yakStrategy)).balanceOf(
            address(this)
        ) - balanceBefore;
        collateralAccounts[msg.sender].collateral +=
            balanceAfter -
            collateralAmount;
        totalCollateralNow += balanceAfter - collateralAmount;
    }

    function returnCollateral(address recipient, uint256 collateralAmount)
        internal
        override
    {
        yakStrategy.withdraw(collateralAmount);
        IERC20(address(ammPair)).safeTransfer(
            recipient,
            getDepositTokensForShares(collateralAmount)
        );
    }

    function viewTargetCollateralAmount(CollateralAccount memory account)
        public
        view
        virtual
        override
        returns (uint256 collateralVal)
    {
        return getDepositTokensForShares(account.collateral);
    }

    function getDepositTokensForShares(uint256 _mintedLP)
        private
        view
        returns (uint256 underlyingValue)
    {
        return yakStrategy.getDepositTokensForShares(_mintedLP);
    }
}
