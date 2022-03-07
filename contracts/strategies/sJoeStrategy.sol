// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./MultiYieldConversionStrategy.sol";
import "../../interfaces/IsJoe.sol";
import "../../interfaces/IJoeBar.sol";

contract sJoeStrategy is MultiYieldConversionStrategy {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    IsJoe public constant sJoe =
        IsJoe(0x1a731B2299E22FbAC282E7094EdA41046343Cb51);
    address public immutable xJoe;
    address public immutable joe;

    constructor(
        address _xJoe,
        address _joe,
        address _wrappedNative,
        address[] memory initialRewardTokens,
        address _roles
    )
        Strategy("sJoe")
        TrancheIDAware(_roles)
        MultiYieldConversionStrategy(_wrappedNative)
    {
        joe = _joe;
        xJoe = _xJoe;

        for (uint256 i; initialRewardTokens.length > i; i++) {
            rewardTokens[_joe].add(initialRewardTokens[i]);
        }
    }

    /// deposit and stake tokens
    function collectCollateral(
        address source,
        address token,
        uint256 collateralAmount
    ) internal override {
        IERC20(token).safeTransferFrom(source, address(this), collateralAmount);

        if (token == xJoe) {
            IJoeBar(xJoe).leave(IERC20(xJoe).balanceOf(address(this)));
        } else 
        
        {
            require(token == joe, "Only for JOE tokens");
        }

        collateralAmount = IERC20(joe).balanceOf(address(this));
        IERC20(joe).safeIncreaseAllowance(
            address(sJoe),
            collateralAmount
        );

        sJoe.deposit(collateralAmount);

        tallyReward(joe);
    }

    /// withdraw back to user
    function returnCollateral(address recipient, address token, uint256 collateralAmount) internal override returns (uint256) {
        require(recipient != address(0), "Don't send to zero address");
        require(token == joe, "Only for JOE tokens");
        sJoe.withdraw(collateralAmount);
        IERC20(joe).safeTransfer(recipient, collateralAmount);
        tallyReward(token);
        return collateralAmount;
    }

    function harvestPartially(address token) external override nonReentrant {
        sJoe.withdraw(0);
        tallyReward(token);
    }

    function viewUnderlyingStrategy(address) public view virtual override returns (address) {
        return address(sJoe);
    }

    /// Initialization, encoding args
    function checkApprovedAndEncode(address token) public view returns (bool, bytes memory) {
        return (
            approvedToken(token),
            ""
        );
    }

    /// Set the tranche token to any token you like, as long as it's JOE
    function _setAndCheckTrancheToken(uint256 trancheId, address token) internal virtual override {
        require(_approvedTokens.contains(token), "Not an approved token");
        _accounts[trancheId].trancheToken = joe;
    }
}
