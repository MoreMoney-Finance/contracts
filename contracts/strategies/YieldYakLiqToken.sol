// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Strategy.sol";

import "../../interfaces/IYakStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract YieldYakLiqToken is Strategy {
    using SafeERC20 for IERC20;

    mapping(address => address) public yakStrategy;

    constructor(address _roles) Strategy("YieldYak liquidation token") TrancheIDAware(_roles) {}

    function collectCollateral(
        address source,
        address token,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        IERC20(token).safeTransferFrom(source, address(this), collateralAmount);

        address yS = yakStrategy[token];
        IERC20(token).approve(yS, collateralAmount);

        uint256 balanceBefore = IERC20(yS).balanceOf(address(this));
        IYakStrategy(yS).deposit(collateralAmount);
        uint256 balanceDelta = IERC20(yS).balanceOf(address(this)) -
            balanceBefore;

        return balanceDelta;
    }

    function returnCollateral(
        address recipient,
        address token,
        uint256 targetAmount
    ) internal override returns (uint256) {
        address yS = yakStrategy[token];
        uint256 receiptAmount = IYakStrategy(yS).getDepositTokensForShares(
            targetAmount
        );
        IYakStrategy(yS).withdraw(receiptAmount);

        IERC20(token).safeTransfer(recipient, targetAmount);

        return receiptAmount;
    }

    function _viewTargetCollateralAmount(
        uint256 collateralAmount,
        address token
    ) internal view override returns (uint256) {
        return
            IYakStrategy(yakStrategy[token]).getDepositTokensForShares(
                collateralAmount
            );
    }

    function setYakStrategy(address token, address strategy)
        external
        onlyOwnerExec
    {
        yakStrategy[token] = strategy;
    }
}
