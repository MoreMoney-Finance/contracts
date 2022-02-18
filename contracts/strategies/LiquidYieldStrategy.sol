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

    address public sAvax = 0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE;
    IERC20 public immutable msAvax;
    IERC20 public immutable mAvax;

    constructor(
        address _msAvax,
        address _mAvax,
        address _wrappedNative,
        address _roles
    )
        Strategy("Liquid Yield")
        TrancheIDAware(_roles)
        MultiYieldConversionStrategy(_wrappedNative)
    {
        msAvax = IERC20(_msAvax);
        mAvax = IERC20(_mAvax);
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
}
