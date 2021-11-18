// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Strategy.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../roles/DependsOnFeeRecipient.sol";

/// A strategy where yield washes ashore in terms of some rewardToken and gets
/// Converted into stablecoin for repayment
abstract contract YieldConversionStrategy is Strategy, DependsOnFeeRecipient {
    using SafeERC20 for IERC20;
    using SafeERC20 for Stablecoin;
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC20 public immutable rewardToken;

    mapping(address => uint256) public totalRewardPerAsset;
    mapping(address => uint256) public totalStableTallied;
    uint256 public totalConvertedStable;
    uint256 public totalRewardCumulative;
    uint256 public currentTalliedRewardReserve;

    uint256 public minimumBidPer10k = 9_700;

    uint256 public feePer10k = 1000;

    constructor(address _rewardToken) {
        rewardToken = IERC20(_rewardToken);
    }

    /// Convert rewardAmount of reward into targetBid amount of the yield token
    function convertReward2Stable(uint256 rewardAmount, uint256 targetBid)
        external
        nonReentrant
    {
        uint256 reward2Convert = min(rewardAmount, currentTalliedRewardReserve);

        require(reward2Convert > 0, "No currently convertible reward");
        uint256 targetValue = _getValue(
            address(rewardToken),
            rewardAmount,
            yieldCurrency()
        );
        require(
            targetBid * 10_000 >= targetValue * minimumBidPer10k,
            "Insufficient bid"
        );

        uint256 stableAmount = (reward2Convert * targetBid) / rewardAmount;

        Stablecoin(yieldCurrency()).burn(msg.sender, stableAmount);

        Stablecoin(yieldCurrency()).mint(
            feeRecipient(),
            (feePer10k * stableAmount) / 10_000
        );

        totalConvertedStable += (stableAmount * (10_000 - feePer10k)) / 10_000;

        rewardToken.safeTransfer(msg.sender, reward2Convert);
        currentTalliedRewardReserve -= reward2Convert;
    }

    /// roll over stable balance into yield to accounts
    function tallyHarvestBalance()
        internal
        virtual
        override
        nonReentrant
        returns (uint256 balance)
    {
        for (uint256 i; _allTokensEver.length() > i; i++) {
            address token = _allTokensEver.at(i);
            balance += tallyHarvestBalance(token);
        }
    }

    /// View outstanding yield that needs to be distributed to accounts of an asset
    function viewHarvestBalance2Tally(address token)
        public
        view
        override
        returns (uint256)
    {
        if (totalRewardCumulative > 0) {
            return
                (totalConvertedStable * totalRewardPerAsset[token]) /
                totalRewardCumulative -
                totalStableTallied[token];
        } else {
            return 0;
        }
    }

    /// Apply harvested yield to accounts, for one token
    function tallyHarvestBalance(address token)
        public
        virtual
        nonReentrant
        returns (uint256 balance)
    {
        balance = viewHarvestBalance2Tally(token);
        TokenMetadata storage tokenMeta = tokenMetadata[token];
        _updateAPF(
            token,
            balance,
            _getValue(token, tokenMeta.totalCollateralNow, yieldCurrency())
        );

        tokenMeta.cumulYieldPerCollateralFP +=
            (balance * FP64) /
            tokenMeta.totalCollateralPast;
        tokenMeta.yieldCheckpoints.push(tokenMeta.cumulYieldPerCollateralFP);
        tokenMeta.totalCollateralPast = tokenMeta.totalCollateralNow;

        totalStableTallied[token] += balance;
    }

    /// Register any excess reward in contract balance and assign it to an asset
    function tallyReward(address token) public nonReentrant {
        uint256 balance = rewardToken.balanceOf(address(this));
        uint256 additionalReward = balance - currentTalliedRewardReserve;
        if (additionalReward > 0) {
            totalRewardPerAsset[token] += additionalReward;
            currentTalliedRewardReserve = balance;
        }
    }

    /// Set how much of a kick-back yield converters get
    function setMinimumBidPer10k(uint256 bidmin) external onlyOwnerExec {
        minimumBidPer10k = bidmin;
    }

    /// Set how large a fee the protocol takes from yield
    function setFeePer10k(uint256 fee) external onlyOwnerExec {
        feePer10k = fee;
    }

    /// This is a repaying strategy
    function yieldType() public pure override returns (IStrategy.YieldType) {
        return IStrategy.YieldType.REPAYING;
    }

    function harvestPartially(address token) public virtual override;
}
