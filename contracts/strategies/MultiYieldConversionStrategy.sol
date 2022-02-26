// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Strategy.sol";
import "../../interfaces/IWETH.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../roles/DependsOnFeeRecipient.sol";

/// A strategy where yield washes ashore in terms of some rewardToken and gets
/// Converted into stablecoin for repayment
abstract contract MultiYieldConversionStrategy is
    Strategy,
    DependsOnFeeRecipient
{
    using SafeERC20 for IERC20;
    using SafeERC20 for Stablecoin;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct AssetYieldMetadata {
        uint256 cumulConvCheckpt;
        uint256 rewardsSinceCheckpt;
    }

    struct RewardConversionCheckpt {
        uint256 convertedStable;
        uint256 sourceRewards;
    }

    // reward => converted amount
    mapping(IERC20 => uint256) cumulConverted2Stable;
    // reward token => yield bearing asset => meta
    mapping(IERC20 => mapping(address => AssetYieldMetadata))
        public assetYieldMeta;
    // reward token => checkpoint => pending
    mapping(IERC20 => mapping(uint256 => RewardConversionCheckpt))
        public pendingConvertedReward;

    // reward token => accounted for stable amount
    mapping(IERC20 => uint256) public rewardBalanceAccountedFor;

    mapping(address => EnumerableSet.AddressSet) internal rewardTokens;

    uint256 public minimumBidPer10k = 9_700;
    uint256 public feePer10k = 1000;
    uint256 public override viewAllFeesEver;

    IWETH public immutable wrappedNative;

    constructor(address _wrappedNative)
    {
        wrappedNative = IWETH(_wrappedNative);
    }

    function viewRewardTokens(address yieldBearingToken)
        external
        view
        returns (address[] memory)
    {
        return rewardTokens[yieldBearingToken].values();
    }

    function addRewardToken(address yieldBearingToken, address rewardToken)
        external
        onlyOwnerExec
    {
        rewardTokens[yieldBearingToken].add(rewardToken);
    }

    function removeRewardToken(address yieldBearingToken, address rewardToken)
        external
        onlyOwnerExec
    {
        rewardTokens[yieldBearingToken].remove(rewardToken);
    }

    /// Convert rewardAmount of reward into targetBid amount of the yield token
    function convertReward2Stable(
        IERC20 rewardToken,
        uint256 rewardAmount,
        uint256 targetBid
    ) external nonReentrant {
        uint256 reward2Convert = min(
            rewardAmount,
            rewardBalanceAccountedFor[rewardToken]
        );

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

        uint256 feeAmount = (feePer10k * stableAmount) / 10_000;
        Stablecoin(yieldCurrency()).mint(feeRecipient(), feeAmount);
        viewAllFeesEver += feeAmount;

        RewardConversionCheckpt storage pending = pendingConvertedReward[
            rewardToken
        ][cumulConverted2Stable[rewardToken]];
        uint256 reward2Store = (stableAmount * (10_000 - feePer10k)) / 10_000;
        pending.convertedStable = reward2Store;
        cumulConverted2Stable[rewardToken] += reward2Store;

        rewardToken.safeTransfer(msg.sender, reward2Convert);
        rewardBalanceAccountedFor[rewardToken] -= reward2Convert;
    }

    /// roll over stable balance into yield to accounts
    function tallyHarvestBalance()
        internal
        virtual
        override
        returns (uint256 balance)
    {
        for (uint256 i; _allTokensEver.length() > i; i++) {
            address token = _allTokensEver.at(i);
            balance += tallyHarvestBalance(token);
        }
    }

    /// View outstanding yield that needs to be distributed to accounts of an asset
    function viewHarvestBalance2Tally(IERC20 rewardToken, address token)
        public
        view
        returns (uint256)
    {
        AssetYieldMetadata storage meta = assetYieldMeta[rewardToken][token];
        RewardConversionCheckpt storage pending = pendingConvertedReward[
            rewardToken
        ][meta.cumulConvCheckpt];
        if (
            cumulConverted2Stable[rewardToken] > meta.cumulConvCheckpt &&
            pending.sourceRewards > 0
        ) {
            return
                (pending.convertedStable * meta.rewardsSinceCheckpt) /
                pending.sourceRewards;
        } else {
            return 0;
        }
    }

    function viewHarvestBalance2Tally(address token)
        public
        view
        override
        returns (uint256 balance)
    {
        EnumerableSet.AddressSet storage rewarders = rewardTokens[token];
        for (uint256 i; rewarders.length() > i; i++) {
            balance += viewHarvestBalance2Tally(IERC20(rewarders.at(i)), token);
        }
    }

    /// Apply harvested yield to accounts, for one token
    function tallyHarvestBalance(IERC20 rewardToken, address token)
        public
        virtual
        returns (uint256 balance)
    {
        balance = viewHarvestBalance2Tally(rewardToken, token);

        AssetYieldMetadata storage meta = assetYieldMeta[rewardToken][token];
        RewardConversionCheckpt storage pending = pendingConvertedReward[
            rewardToken
        ][meta.cumulConvCheckpt];

        if (cumulConverted2Stable[rewardToken] > meta.cumulConvCheckpt) {
            if (balance > 0) {
                pending.convertedStable -= balance;
                pending.sourceRewards -= meta.rewardsSinceCheckpt;

                TokenMetadata storage tokenMeta = tokenMetadata[token];

                uint256 cumulYieldPerCollateralFP = tokenMeta
                    .yieldCheckpoints
                    .length > 0
                    ? tokenMeta.yieldCheckpoints[
                        tokenMeta.yieldCheckpoints.length - 1
                    ]
                    : 0;

                if (tokenMeta.totalCollateralThisPhase > 0) {
                    uint256 yieldThisPhase = (balance * FP64) /
                        tokenMeta.totalCollateralThisPhase;
                    tokenMeta.yieldCheckpoints.push(
                        cumulYieldPerCollateralFP + yieldThisPhase
                    );
                } else {
                    // Since nobody has been participating in this period, send to fee recipient
                    tokenMeta.yieldCheckpoints.push(cumulYieldPerCollateralFP);
                    Stablecoin(yieldCurrency()).mint(feeRecipient(), balance);
                    viewAllFeesEver += balance;
                }

                tokenMeta.totalCollateralThisPhase = tokenMeta
                    .totalCollateralNow;
            }
            meta.rewardsSinceCheckpt = 0;
            meta.cumulConvCheckpt = cumulConverted2Stable[rewardToken];
        }
    }

    function tallyHarvestBalance(address token)
        public
        virtual
        returns (uint256 balance)
    {
        EnumerableSet.AddressSet storage rewarders = rewardTokens[token];
        for (uint256 i; rewarders.length() > i; i++) {
            balance += tallyHarvestBalance(IERC20(rewarders.at(i)), token);
        }
    }

    /// Register any excess reward in contract balance and assign it to an asset
    function tallyReward(IERC20 rewardToken, address token) public {
        tallyHarvestBalance(token);
        uint256 balance = rewardToken.balanceOf(address(this));
        uint256 additionalReward = balance -
            rewardBalanceAccountedFor[rewardToken];
        if (additionalReward > 0) {
            AssetYieldMetadata storage meta = assetYieldMeta[rewardToken][
                token
            ];
            RewardConversionCheckpt storage pending = pendingConvertedReward[
                rewardToken
            ][meta.cumulConvCheckpt];

            meta.rewardsSinceCheckpt += additionalReward;
            pending.sourceRewards += additionalReward;

            rewardBalanceAccountedFor[rewardToken] = balance;
        }
    }

    function tallyReward(address token) public {
        EnumerableSet.AddressSet storage rewarders = rewardTokens[token];
        if (address(this).balance > 0) {
            wrappedNative.deposit{value:address(this).balance}();
        }
        for (uint256 i; rewarders.length() > i; i++) {
            tallyReward(IERC20(rewarders.at(i)), token);
        }
    }

    /// Set how much of a kick-back yield converters get
    function setMinimumBidPer10k(uint256 bidmin) external onlyOwnerExec {
        minimumBidPer10k = bidmin;
        emit ParameterUpdated("Minimum bid", bidmin);
    }

    /// Set how large a fee the protocol takes from yield
    function setFeePer10k(uint256 fee) external onlyOwnerExec {
        feePer10k = fee;
        emit ParameterUpdated("Protocol yield fee", fee);
    }

    /// This is a repaying strategy
    function yieldType() public pure override returns (IStrategy.YieldType) {
        return IStrategy.YieldType.REPAYING;
    }

    function harvestPartially(address token) external virtual override;

    /// Internal, collect yield and disburse it to recipient
    function _collectYield(
        uint256 trancheId,
        address currency,
        address recipient
    ) internal virtual override returns (uint256 yieldEarned) {
        require(recipient != address(0), "Don't send to zero address");
        require(
            currency == yieldCurrency(),
            "Only use official yield currency"
        );

        CollateralAccount storage account = _accounts[trancheId];
        TokenMetadata storage tokenMeta = tokenMetadata[
            trancheToken(trancheId)
        ];
        if (account.collateral > 0) {
            yieldEarned = _viewYield(account, tokenMeta, currency);
            Stablecoin(currency).mint(recipient, yieldEarned);
        }

        account.yieldCheckptIdx = tokenMeta.yieldCheckpoints.length;
    }
}
