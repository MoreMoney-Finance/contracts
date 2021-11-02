// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Strategy.sol";

contract SimpleHoldingStrategy is Strategy {
    using SafeERC20 for IERC20;

    constructor(address _roles)
        Strategy("Simple holding strategy")
        TrancheIDAware(_roles)
    {}

    function collectCollateral(
        address source,
        address token,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        IERC20(token).safeTransferFrom(source, address(this), collateralAmount);
        return collateralAmount;
    }

    function returnCollateral(
        address recipient,
        address token,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        IERC20(token).safeTransfer(recipient, collateralAmount);
        return collateralAmount;
    }

    function _viewTargetCollateralAmount(uint256 collateralAmount, address)
        internal
        pure
        override
        returns (uint256)
    {
        return collateralAmount;
    }

    function checkApprovedAndEncode(address token)
        public
        view
        returns (bool, bytes memory)
    {
        return (approvedToken(token), abi.encode());
    }
}
