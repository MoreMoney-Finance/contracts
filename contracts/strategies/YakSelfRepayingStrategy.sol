// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./MultiYieldConversionStrategy.sol";
import "../../interfaces/IMasterYak.sol";

contract YakSelfRepayingStrategy is MultiYieldConversionStrategy {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    IMasterYak public constant masterYak =
        IMasterYak(0x0cf605484A512d3F3435fed77AB5ddC0525Daf5f);
    address public immutable yak;

    constructor(
        address _yak,
        address _wrappedNative,
        address[] memory initialRewardTokens,
        address _roles
    )
        Strategy("Yak")
        TrancheIDAware(_roles)
        MultiYieldConversionStrategy(_wrappedNative)
    {
        yak = _yak;

        for (uint256 i; initialRewardTokens.length > i; i++) {
            rewardTokens[_yak].add(initialRewardTokens[i]);
        }
    }

    /// deposit and stake tokens
    function collectCollateral(
        address source,
        address token,
        uint256 collateralAmount
    ) internal override {
        IERC20(token).safeTransferFrom(source, address(this), collateralAmount);
        require(token == yak, "Only for YAK tokens");
        collateralAmount = IERC20(yak).balanceOf(address(this));
        IERC20(yak).safeIncreaseAllowance(address(yak), collateralAmount);
        masterYak.deposit(0, collateralAmount);
        tallyReward(yak);
    }

    /// Withdraw from yy strategy and return to user
    function returnCollateral(
        address recipient,
        address token,
        uint256 collateralAmount
    ) internal virtual override returns (uint256) {
        require(recipient != address(0), "Don't send to zero address");
        require(token == yak, "Only for YAK tokens");

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        masterYak.withdraw(0, collateralAmount);
        uint256 balanceDelta = IERC20(token).balanceOf(address(this)) -
            balanceBefore;

        IERC20(token).safeTransfer(recipient, balanceDelta);

        return balanceDelta;
    }

    function harvestPartially(address token) external override nonReentrant {
        masterYak.withdraw(0, 0);
        tallyReward(token);
    }

    function viewUnderlyingStrategy(address)
        public
        view
        virtual
        override
        returns (address)
    {
        return address(yak);
    }

    /// Initialization, encoding args
    function checkApprovedAndEncode(address token)
        public
        view
        returns (bool, bytes memory)
    {
        return (approvedToken(token), "");
    }

    /// Set the tranche token to any token you like, as long as it's JOE
    function _setAndCheckTrancheToken(uint256 trancheId, address token)
        internal
        virtual
        override
    {
        require(_approvedTokens.contains(token), "Not an approved token");
        _accounts[trancheId].trancheToken = yak;
    }
}
