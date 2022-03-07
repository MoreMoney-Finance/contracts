// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./MultiYieldConversionStrategy.sol";
import "../roles/DependsOnLyRebalancer.sol";
import "../roles/DependsOnLyRedistributorMAvax.sol";
import "../roles/DependsOnLyRedistributorMSAvax.sol";

contract LiquidYieldStrategy is
    MultiYieldConversionStrategy,
    DependsOnLyRebalancer,
    DependsOnLyRedistributorMAvax,
    DependsOnLyRedistributorMSAvax
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    address immutable sAvax;
    IERC20 public immutable msAvax;
    IERC20 public immutable mAvax;

    constructor(
        address _sAvax,
        address _msAvax,
        address _mAvax,
        address _wrappedNative,
        address[] memory initialRewardTokens,
        address _roles
    )
        Strategy("Liquid Yield")
        TrancheIDAware(_roles)
        MultiYieldConversionStrategy(_wrappedNative)
    {
        msAvax = IERC20(_msAvax);
        mAvax = IERC20(_mAvax);

        sAvax = _sAvax;

        for (uint256 i; initialRewardTokens.length > i; i++) {
            rewardTokens[_sAvax].add(initialRewardTokens[i]);
            rewardTokens[_wrappedNative].add(initialRewardTokens[i]);
        }
    }

    /// deposit and stake tokens
    function collectCollateral(
        address source,
        address token,
        uint256 collateralAmount
    ) internal override {
        IERC20(token).safeTransferFrom(source, address(this), collateralAmount);
        LyRebalancer rebalancer = lyRebalancer();
        IERC20(token).safeIncreaseAllowance(
            address(rebalancer),
            collateralAmount
        );
        if (token == address(wrappedNative)) {
            rebalancer.mintMAvax(collateralAmount);
            LyRedistributor redist = lyRedistributorMAvax();

            mAvax.safeIncreaseAllowance(address(redist), collateralAmount);
            redist.stake(collateralAmount);
        } else if (token == sAvax) {
            rebalancer.mintMsAvax(collateralAmount);
            LyRedistributor redist = lyRedistributorMSAvax();

            msAvax.safeIncreaseAllowance(address(redist), collateralAmount);
            redist.stake(collateralAmount);
        } else {
            require(false, "Strategy only for avax and savax");
        }
        tallyReward(token);
    }

    /// withdraw back to user
    function returnCollateral(
        address recipient,
        address token,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        require(recipient != address(0), "Don't send to zero address");

        LyRebalancer rebalancer = lyRebalancer();
        if (token == address(wrappedNative)) {
            lyRedistributorMAvax().unstake(collateralAmount, address(this));
            rebalancer.burnMAvax2wAvax(collateralAmount, recipient);
        } else if (token == sAvax) {
            lyRedistributorMSAvax().unstake(collateralAmount, address(this));
            rebalancer.burnMsAvax(collateralAmount, recipient);
        }

        return collateralAmount;
    }

    function harvestPartially(address token) external override nonReentrant {
        // lyLptHolder.harvestPartially();
        if (token == address(wrappedNative)) {
            lyRedistributorMAvax().harvest();
        } else if (token == sAvax) {
            lyRedistributorMSAvax().harvest();
        }
        tallyReward(token);
    }

    function viewUnderlyingStrategy(address)
        public
        view
        virtual
        override
        returns (address)
    {
        return address(lyRebalancer());
    }

    /// Initialization, encoding args
    function checkApprovedAndEncode(
        address token
    ) public view returns (bool, bytes memory) {
        return (
            approvedToken(token),
            ""
        );
    }
}
