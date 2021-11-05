// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Strategy.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../roles/DependsOnFeeRecipient.sol";

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

    uint256 public minimumBidPer10k = 9_600;

    uint256 public feePer10k = 1000;

    constructor(address _rewardToken) {
        rewardToken = IERC20(_rewardToken);
    }

    function convertReward2Stable(uint256 conversionAmount, uint256 usdmBid)
        external
    {
        uint256 reward2Convert = min(conversionAmount, currentTalliedRewardReserve);

        require(reward2Convert > 0, "No currently convertible reward");
        uint256 targetValue = _getValue(address(rewardToken), conversionAmount, address(stableCoin()));
        require(usdmBid * 10_000 >= targetValue * minimumBidPer10k, "Insufficient bid");

        uint256 stableAmount = reward2Convert * usdmBid / conversionAmount;

        stableCoin().burn(
            msg.sender,
            stableAmount
        );

        stableCoin().mint(feeRecipient(), feePer10k * stableAmount / 10_000);

        totalConvertedStable += stableAmount * (10_000 - feePer10k) / 10_000;

        rewardToken.safeTransfer(msg.sender, reward2Convert);
        currentTalliedRewardReserve -= reward2Convert;
    }

    /// roll over stable balance into yield to accounts
    function tallyHarvestBalance() internal virtual override returns (uint256 balance) {
        for (uint256 i; _allTokensEver.length() > i; i++) {
            address token = _allTokensEver.at(i);
            balance += tallyHarvestBalance(token);
        }
    }

    function tallyHarvestBalance(address token) public virtual returns (uint256 balance) {
        balance = totalConvertedStable * totalRewardPerAsset[token] / totalRewardCumulative - totalStableTallied[token];

        // TODO: set apf here
        TokenMetadata storage tokenMeta = tokenMetadata[token];
        tokenMeta.cumulYieldPerCollateralFP +=
            (balance * FP64) /
            tokenMeta.totalCollateralPast;
        tokenMeta.yieldCheckpoints.push(
            tokenMeta.cumulYieldPerCollateralFP
        );
        tokenMeta.totalCollateralPast = tokenMeta.totalCollateralNow;

        totalStableTallied[token] += balance;
    }

    function tallyReward(address token) public {
        uint256 balance = rewardToken.balanceOf(address(this));
        uint256 additionalReward = balance - currentTalliedRewardReserve;
        if (additionalReward > 0) {
            totalRewardPerAsset[token] += additionalReward;
            currentTalliedRewardReserve = balance;
        }
    }

    function setMinimumBidPer10k(uint256 bidmin) external onlyOwnerExec {
        minimumBidPer10k = bidmin;
    }

    function setFeePer10k(uint256 fee) external onlyOwnerExec {
        feePer10k = fee;
    }
}
