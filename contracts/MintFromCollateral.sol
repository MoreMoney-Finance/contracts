// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./RoleAware.sol";
import "./Stablecoin.sol";

abstract contract MintFromCollateral is RoleAware {
    struct CollateralAccount {
        uint256 collateral;
        uint256 stable;

        uint256 yieldCheckpt;
        uint256 collateralIntegralCheckpt;
        uint256 lastUpdateBlock;
    }

    uint256 public cumulYieldPerCollateralBlocks;
    uint256 public cumulYieldLastUpdated;
    uint256 public collateralIntegralHarvestCheckpt;

    uint256 public totalCollateralIntegral;
    uint256 public totalCollateralNow;
    uint256 public totalCollateralLastUpdated;
    uint256 internal constant FP64 = 2 ** 64;

    uint256 public reservePercent;

    mapping(address => CollateralAccount) collateralAccounts;

    constructor(address _roles) RoleAware(_roles) {}

    function getStable(uint256 collateralAmount, uint256 stableAmount)
        external
    {
        CollateralAccount storage account = collateralAccounts[msg.sender];

        updateStable(msg.sender, account);

        account.collateral += collateralAmount;
        account.stable += stableAmount + mintingFee(stableAmount);

        totalCollateralNow += collateralAmount;

        account.collateralIntegralCheckpt = totalCollateralIntegral;

        if (stableAmount > 0) {
            require(
                getCollateralValue(account.collateral) * reservePercent >=
                    account.stable * 100,
                "Exceeds reserve ratio"
            );
        }

        collectCollateral(msg.sender, collateralAmount);
        Stablecoin(stableCoin()).mint(msg.sender, stableAmount);
    }

    function getCollateral(uint256 collateralAmount, uint256 stableAmount)
        external
    {
        CollateralAccount storage account = collateralAccounts[msg.sender];

        updateStable(msg.sender, account);

        account.collateral -= collateralAmount;
        account.stable -= stableAmount;

        totalCollateralNow -= collateralAmount;

        if (account.stable > 0) {
            require(
                getCollateralValue(account.collateral) * reservePercent >=
                    account.stable * 100,
                "Exceeds reserve ratio"
            );
        }

        returnCollateral(msg.sender, collateralAmount);
        Stablecoin(stableCoin()).burn(msg.sender, stableAmount);
    }

    function setReservePercent(uint256 _newVal) external onlyOwnerExec {
        reservePercent = _newVal;
    }

    function _earnedYield(CollateralAccount storage account) internal view returns (uint256) {
        uint256 blockDelta = cumulYieldLastUpdated - account.lastUpdateBlock;
        uint256 yieldDelta = cumulYieldPerCollateralBlocks - account.yieldCheckpt;
       return account.collateral * blockDelta * yieldDelta / FP64;
    }

    function updateCollateralIntegral() internal {
        totalCollateralIntegral += totalCollateralNow * (block.number - totalCollateralLastUpdated);
        totalCollateralLastUpdated = block.number;
    }

    function updateStable(address holder, CollateralAccount storage account) internal {
        updateCollateralIntegral();
        account.lastUpdateBlock = block.number;

        if (account.collateral > 0) {
            uint256 yieldEarned = _earnedYield(account);
            if (yieldEarned > account.stable) {
                Stablecoin(stableCoin()).mint(holder, yieldEarned - account.stable);
                account.stable = 0;
            } else {
                account.stable -= yieldEarned;
            }
        }

        account.yieldCheckpt = cumulYieldPerCollateralBlocks;
        account.lastUpdateBlock = block.number;
    }

    function tallyHarvest(uint256 amount) internal {
        updateCollateralIntegral();
        uint256 collateralIntegralDelta = totalCollateralIntegral - collateralIntegralHarvestCheckpt;
        collateralIntegralHarvestCheckpt = totalCollateralIntegral;
        cumulYieldLastUpdated = block.number;

        cumulYieldPerCollateralBlocks += amount * FP64 / collateralIntegralDelta;
    }

    function tallyHarvestBalance() public returns (uint256 balance) {
        Stablecoin stable = Stablecoin(stableCoin());
        balance = stable.balanceOf(address(this));
        if (balance > 0) {
            stable.burn(address(this), balance);
        }

        tallyHarvest(balance);
    }

    function collectCollateral(address source, uint256 collateralAmount)
        internal
        virtual;

    function returnCollateral(address recipient, uint256 collateralAmount)
        internal
        virtual;

    function getCollateralValue(uint256 collateralAmount)
        public
        virtual
        returns (uint256);

    function harvestYield() public virtual returns (uint256);

    function mintingFee(uint256 stableAmount) public virtual returns (uint256);
}

// aggregate reward
