// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./RoleAware.sol";
import "./Stablecoin.sol";

abstract contract MintFromCollateral is RoleAware {
    struct CollateralAccount {
        uint256 collateral;
        uint256 stable;

        uint256 yieldCheckptIdx;
        uint256 withdrawalLockup;
    }

    struct LiquidationRecord {
        address liquidator;
        uint256 bid;

        uint256 collateral;
        uint256 stable;

        uint256 tstamp;
    }

    event Liquidation(address indexed liquidated, uint256 bid, uint256 collateral, uint256 stable);

    uint256[] public yieldCheckpoints;
    uint256 public cumulYieldPerCollateralFP;

    uint256 public totalCollateralPast;
    uint256 public totalCollateralNow;
    uint256 internal constant FP64 = 2 ** 64;

    uint256 public reservePermil;
    uint256 public liquidationRatioPermil;
    uint256 public liquidationBidWindow;

    mapping(address => CollateralAccount) public collateralAccounts;
    mapping(address => LiquidationRecord) public liquidationRecords;

    constructor(address _roles) RoleAware(_roles) {}

    function getStable(uint256 collateralAmount, uint256 stableAmount)
        virtual
        external
    {
        CollateralAccount storage account = collateralAccounts[msg.sender];
        require(stableAmount == 0 || block.timestamp > account.withdrawalLockup, "Wait until lockup period over");

        updateStable(msg.sender, account);

        account.collateral += collateralAmount;
        account.stable += stableAmount + mintingFee(stableAmount);

        totalCollateralNow += collateralAmount;

        if (stableAmount > 0) {
            require(_collateralizationPermil(account) >= reservePermil,
                "Withdraw violates reserve ratio"
            );
        }

        collectCollateral(msg.sender, collateralAmount);
        Stablecoin(stableCoin()).mint(msg.sender, stableAmount);
    }

    function getCollateral(uint256 collateralAmount, uint256 stableAmount)
        virtual
        external
    {
        CollateralAccount storage account = collateralAccounts[msg.sender];
        require(collateralAmount == 0 || block.timestamp > account.withdrawalLockup, "Wait until lockup period over");

        updateStable(msg.sender, account);

        account.collateral -= collateralAmount;
        account.stable -= stableAmount;

        totalCollateralNow -= collateralAmount;

        if (account.stable > 0) {
            require(_collateralizationPermil(account) >= reservePermil,
                "Withdraw violates reserve ratio"
            );
        }

        returnCollateral(msg.sender, collateralAmount);
        Stablecoin(stableCoin()).burn(msg.sender, stableAmount);
    }

    function setReservePermil(uint256 _newVal) external onlyOwnerExec {
        reservePermil = _newVal;
    }

    function _earnedYield(CollateralAccount storage account) virtual internal view returns (uint256) {
        if (yieldCheckpoints.length > account.yieldCheckptIdx) {
            uint256 yieldDelta = cumulYieldPerCollateralFP - yieldCheckpoints[account.yieldCheckptIdx];
           return account.collateral * yieldDelta / FP64;
        } else { 
            return 0;
        }
    }

    function updateStable(address holder, CollateralAccount storage account) virtual internal {
        if (account.collateral > 0) {
            uint256 yieldEarned = _earnedYield(account);
            if (yieldEarned > account.stable) {
                Stablecoin(stableCoin()).mint(holder, yieldEarned - account.stable);
                account.stable = 0;
            } else {
                account.stable -= yieldEarned;
            }
        }

        // accounts participate in yield distribution starting after the next checkpoint
        account.yieldCheckptIdx = yieldCheckpoints.length;
    }

    function tallyHarvestBalance() virtual internal returns (uint256 balance) {
        Stablecoin stable = Stablecoin(stableCoin());
        balance = stable.balanceOf(address(this));
        if (balance > 0) {
            stable.burn(address(this), balance);

            cumulYieldPerCollateralFP += balance * FP64 / totalCollateralPast;
            yieldCheckpoints.push(cumulYieldPerCollateralFP);
            totalCollateralPast = totalCollateralNow;
        }
    }

    function collateralizationPermil(address account) external returns (uint256) {
        return _collateralizationPermil(collateralAccounts[account]);
    }

    function _collateralizationPermil(CollateralAccount storage account) internal returns (uint256) {
        return getCollateralValue(account.collateral) * 1000 / account.stable;
    }

    function liquidatable(address account) virtual external returns (bool) {
        return _liquidatable(collateralAccounts[account]);
    }

    function _liquidatable(CollateralAccount storage account) internal returns (bool) {
        return liquidationRatioPermil > _collateralizationPermil(account);
    }

    function liquidate(address candidate, uint256 bid) virtual external {
        CollateralAccount storage liqAccount = collateralAccounts[candidate];
        LiquidationRecord storage liqRecord = liquidationRecords[candidate];
        Stablecoin stable = Stablecoin(stableCoin());

        // withdraw the bid
        stable.burn(msg.sender, bid);
        
        if (liqRecord.tstamp + liquidationBidWindow >= block.timestamp) {
            require(bid > liqRecord.bid, "Bid too low");

            // return old bid
            stable.mint(liqRecord.liquidator, liqRecord.bid);

            // distribute excess bid
            uint256 bidDelta = bid - liqRecord.bid;
            stable.mint(feeRecipient(), bidDelta / 2);
            stable.mint(candidate, bidDelta / 2);

            // unwind assets from outbid liquidator
            CollateralAccount storage outbidAccount = collateralAccounts[liqRecord.liquidator];
            updateStable(liqRecord.liquidator, outbidAccount);
            outbidAccount.stable -= liqRecord.stable;
            outbidAccount.collateral -= liqRecord.collateral;

        } else {
            updateStable(candidate, liqAccount);
            require(_liquidatable(liqAccount), "Account is not liquidatable");

            stable.mint(feeRecipient(), bid / 2);
            stable.mint(candidate, bid / 2);

            liqRecord.stable = liqAccount.stable;
            liqRecord.collateral = liqAccount.collateral;

            delete collateralAccounts[candidate];
        }

        liqRecord.liquidator = msg.sender;
        liqRecord.tstamp = block.timestamp;
        liqRecord.bid = bid;

        CollateralAccount storage ourAccount = collateralAccounts[msg.sender];
        updateStable(msg.sender, ourAccount);
        ourAccount.stable += liqRecord.stable;
        ourAccount.collateral += liqRecord.collateral;
        ourAccount.withdrawalLockup = block.timestamp + liquidationBidWindow;

        emit Liquidation(candidate, bid, liqRecord.collateral, liqRecord.stable);
    }

    /// Can be incentivized externally
    function liquidateUnderwater(address candidate) virtual external {
        CollateralAccount storage liqAccount = collateralAccounts[candidate];
        require(1030 >= _collateralizationPermil(liqAccount), "Account is not underwater");
        returnCollateral(feeRecipient(), liqAccount.collateral);
        totalCollateralNow -= liqAccount.collateral;
        delete collateralAccounts[candidate];
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

    function mintingFee(uint256 stableAmount) public virtual returns (uint256);
}

// aggregate reward
