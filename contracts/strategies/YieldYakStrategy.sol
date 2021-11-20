// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Strategy.sol";

import "../../interfaces/IYakStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../roles/DependsOnFeeRecipient.sol";

/// Compounding strategy using yieldyak
contract YieldYakStrategy is Strategy, DependsOnFeeRecipient {
    using SafeERC20 for IERC20;

    mapping(address => address) public yakStrategy;
    mapping(uint256 => uint256) public depositedShares;
    mapping(address => uint256) public withdrawnFees;
    mapping(uint256 => uint256) public trancheAPFLastUpdated;

    uint256 feePer10k = 1000;

    constructor(address _roles)
        Strategy("YieldYak liquidation token")
        TrancheIDAware(_roles)
    {
        apfSmoothingPer10k = 500;
    }

    /// Withdraw from user account and deposit into yieldyak strategy
    function collectCollateral(
        address source,
        address token,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        IERC20(token).safeTransferFrom(source, address(this), collateralAmount);

        address yS = yakStrategy[token];
        IERC20(token).approve(yS, collateralAmount);

        uint256 balanceBefore = IERC20(yS).balanceOf(address(this));
        IYakStrategy(yS).deposit(collateralAmount);
        uint256 balanceDelta = IERC20(yS).balanceOf(address(this)) -
            balanceBefore;

        return balanceDelta;
    }

    /// Withdraw from yy strategy and return to user
    function returnCollateral(
        address recipient,
        address token,
        uint256 targetAmount
    ) internal override returns (uint256) {
        require(recipient != address(0), "Don't send to zero address");

        address yS = yakStrategy[token];
        uint256 receiptAmount = IYakStrategy(yS).getSharesForDepositTokens(
            targetAmount
        );
        IYakStrategy(yS).withdraw(receiptAmount);

        IERC20(token).safeTransfer(recipient, targetAmount);

        return receiptAmount;
    }

    /// View collateral owned by tranche, taking into account compounding and fee
    function viewTargetCollateralAmount(uint256 trancheId)
        public
        view
        override
        returns (uint256)
    {
        CollateralAccount storage account = _accounts[trancheId];
        uint256 originalAmount = account.collateral;
        uint256 currentWithYield = IYakStrategy(
            yakStrategy[account.trancheToken]
        ).getDepositTokensForShares(depositedShares[trancheId]);

        uint256 feeFactor = 10_000 - feePer10k;
        return
            originalAmount +
            (currentWithYield * feeFactor) /
            10_000 -
            (originalAmount * feeFactor) /
            10_000;
    }

    /// Set the yy strategy for a token
    function setYakStrategy(address token, address strategy)
        external
        onlyOwnerExec
    {
        yakStrategy[token] = strategy;
    }

    /// Check whether a token is approved and encode params
    function checkApprovedAndEncode(address token, address strategy)
        public
        view
        returns (bool, bytes memory)
    {
        return (approvedToken(token), abi.encode(strategy));
    }

    /// Internal, initialize a token
    function _approveToken(address token, bytes calldata data)
        internal
        override
    {
        address _yakStrategy = abi.decode(data, (address));
        require(
            IYakStrategy(_yakStrategy).depositToken() == token,
            "Provided yak strategy does not take token as deposit"
        );
        yakStrategy[token] = _yakStrategy;

        super._approveToken(token, data);
    }

    /// Internal, applies compounding to the tranche balance, minus fees
    function _collectYield(
        uint256 trancheId,
        address,
        address
    ) internal override returns (uint256) {
        CollateralAccount storage account = _accounts[trancheId];
        if (account.collateral > 0) {
            address token = account.trancheToken;
            TokenMetadata storage tokenMeta = tokenMetadata[token];
            uint256 newAmount = viewTargetCollateralAmount(trancheId);
            uint256 oldAmount = account.collateral;

            if (newAmount > oldAmount) {
                // disburse fee
                returnCollateral(
                    feeRecipient(),
                    token,
                    (feePer10k * (newAmount - oldAmount)) / (10_000 - feePer10k)
                );

                uint256 lastUpdated = trancheAPFLastUpdated[trancheId];
                uint256 timeDelta = lastUpdated > 0
                    ? block.timestamp - lastUpdated
                    : 1 weeks;
                _updateAPF(timeDelta, token, newAmount - oldAmount, oldAmount);
            }

            // prevent underflow on withdrawals
            tokenMeta.totalCollateralNow =
                tokenMeta.totalCollateralNow +
                newAmount -
                oldAmount;
            account.collateral = newAmount;

            depositedShares[trancheId] = IYakStrategy(yakStrategy[token])
                .getSharesForDepositTokens(newAmount);
        }
        trancheAPFLastUpdated[trancheId] = block.timestamp;
        return 0;
    }

    /// Set deposited shares
    function _handleBalanceUpdate(
        uint256 trancheId,
        address token,
        uint256 balance
    ) internal override {
        depositedShares[trancheId] = IYakStrategy(yakStrategy[token])
            .getSharesForDepositTokens(balance);
    }

    /// Deposit tokens for user
    function _deposit(
        address depositor,
        uint256 trancheId,
        uint256 amount,
        address yieldCurrency,
        address yieldRecipient
    ) internal override {
        super._deposit(
            depositor,
            trancheId,
            amount,
            yieldCurrency,
            yieldRecipient
        );
        CollateralAccount storage account = _accounts[trancheId];
        depositedShares[trancheId] = IYakStrategy(
            yakStrategy[account.trancheToken]
        ).getSharesForDepositTokens(_accounts[trancheId].collateral);
    }

    /// Withdraw tokens for user
    function _withdraw(
        uint256 trancheId,
        uint256 amount,
        address yieldCurrency,
        address recipient
    ) internal override {
        super._withdraw(trancheId, amount, yieldCurrency, recipient);
        CollateralAccount storage account = _accounts[trancheId];
        uint256 remainingBalance = account.collateral;
        if (remainingBalance > 0) {
            depositedShares[trancheId] = IYakStrategy(
                yakStrategy[account.trancheToken]
            ).getSharesForDepositTokens(remainingBalance);
        }
    }

    /// TVL per token
    function _viewTVL(address token) public view override returns (uint256) {
        address strat = yakStrategy[token];
        return
            IYakStrategy(strat).getDepositTokensForShares(
                IERC20(strat).balanceOf(address(this))
            );
    }

    /// compounding
    function yieldType() public pure override returns (IStrategy.YieldType) {
        return IStrategy.YieldType.COMPOUNDING;
    }

    /// Call reinvest
    function harvestPartially(address token) public override nonReentrant {
        IYakStrategy(yakStrategy[token]).reinvest();
    }
}
