// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YieldYakStrategy2.sol";

contract YieldYakPermissiveStrategy2 is YieldYakStrategy2 {
    using SafeERC20 for IERC20;

    address public constant stakedGlp =
        0x5643F4b25E36478eE1E90418d5343cb6591BcB9d;
    address public constant fsGlp = 0x9e295B5B976a184B14aD8cd72413aD846C299660;

    constructor(address _roles) YieldYakStrategy2(_roles) {}

    /// Internal, initialize a token
    function _approveToken(address token, bytes calldata data)
        internal
        override
    {
        require(token == fsGlp, "Strategy only accepts fsGLP");
        changeUnderlyingStrat(token, abi.decode(data, (address)));
        Strategy2._approveToken(token, data);
    }

    function collectCollateral(
        address source,
        address token,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        require(token == fsGlp, "Strategy only handles fsGLP");
        IERC20(stakedGlp).safeTransferFrom(
            source,
            address(this),
            collateralAmount
        );

        address yS = yakStrategy[token];
        IERC20(stakedGlp).safeIncreaseAllowance(yS, collateralAmount);
        uint256 balanceBefore = IERC20(yS).balanceOf(address(this));
        IYakStrategy(yS).deposit(collateralAmount);

        return
            IYakStrategy(yS).getDepositTokensForShares(
                IERC20(yS).balanceOf(address(this)) - balanceBefore
            );
    }

    function returnCollateral(
        address recipient,
        address token,
        uint256 targetAmount
    ) internal override returns (uint256) {
        require(token == fsGlp, "Strategy only handles fsGLP");
        require(recipient != address(0), "Don't send to zero address");

        address yS = yakStrategy[token];
        uint256 receiptAmount = IYakStrategy(yS).getSharesForDepositTokens(
            targetAmount
        );

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IYakStrategy(yS).withdraw(receiptAmount);
        uint256 balanceDelta = IERC20(token).balanceOf(address(this)) -
            balanceBefore;

        IERC20(stakedGlp).safeTransfer(recipient, balanceDelta);

        return balanceDelta;
    }
}
