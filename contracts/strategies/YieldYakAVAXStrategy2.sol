// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./YieldYakStrategy2.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IWETH.sol";

contract YieldYakAVAXStrategy2 is YieldYakStrategy2 {
    using SafeERC20 for IERC20;

    IWETH public immutable wrappedNative;

    constructor(address _wrappedNative, address _roles)
        YieldYakStrategy2(_roles)
    {
        wrappedNative = IWETH(_wrappedNative);
    }

    /// Withdraw from user account and deposit into yieldyak strategy
    function collectCollateral(
        address source,
        address token,
        uint256 collateralAmount
    ) internal override {
        require(token == address(wrappedNative), "Only for WAVAX");
        IERC20(token).safeTransferFrom(source, address(this), collateralAmount);
        wrappedNative.withdraw(collateralAmount);

        address yS = yakStrategy[token];
        IYakStrategy(yS).deposit{value: collateralAmount}();
    }

    /// Withdraw from yy strategy and return to user
    function returnCollateral(
        address recipient,
        address token,
        uint256 targetAmount
    ) internal override returns (uint256) {
        require(recipient != address(0), "Don't send to zero address");
        require(token == address(wrappedNative), "Only for WAVAX");

        address yS = yakStrategy[token];
        uint256 receiptAmount = IYakStrategy(yS).getSharesForDepositTokens(
            targetAmount
        );

        uint256 balanceBefore = address(this).balance;
        IYakStrategy(yS).withdraw(receiptAmount);
        uint256 balanceDelta = address(this).balance - balanceBefore;

        wrappedNative.deposit{value: balanceDelta}();

        IERC20(token).safeTransfer(recipient, balanceDelta);

        return balanceDelta;
    }

    /// Internal, initialize a token
    function _approveToken(address token, bytes calldata data)
        internal
        override
    {
        require(token == address(wrappedNative), "Only for WAVAX");
        super._approveToken(token, data);
    }
}
