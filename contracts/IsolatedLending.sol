// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./roles/RoleAware.sol";
import "./Tranche.sol";
import "./roles/CallsStableCoinMintBurn.sol";
import "./roles/DependsOnLiquidator.sol";
import "./roles/DependsOnFeeRecipient.sol";
import "./oracles/OracleAware.sol";

/// Centerpiece of CDP: lending minted stablecoin against collateral
/// Collateralized debt positions are expressed as ERC721 tokens (via Tranche)
contract IsolatedLending is
    OracleAware,
    Tranche,
    CallsStableCoinMintBurn,
    DependsOnLiquidator,
    DependsOnFeeRecipient
{
    struct AssetConfig {
        uint256 debtCeiling;
        uint256 feePer10k;
        uint256 totalDebt;
    }

    mapping(address => AssetConfig) public assetConfigs;

    mapping(uint256 => uint256) public trancheDebt;
    uint256 public pendingFees;

    constructor(address _roles)
        Tranche("MoreMoney Isolated Lending", "MMIL", _roles)
    {
        _charactersPlayed.push(ISOLATED_LENDING);
        _rolesPlayed.push(FUND_TRANSFERER);
    }

    /// Set the debt ceiling for an asset
    function setAssetDebtCeiling(address token, uint256 ceiling)
        external
        onlyOwnerExecDisabler
    {
        assetConfigs[token].debtCeiling = ceiling;
    }

    /// Set minting fee per an asset
    function setFeesPer10k(address token, uint256 fee) external onlyOwnerExec {
        assetConfigs[token].feePer10k = fee;
    }

    /// Set central parameters per an asset
    function configureAsset(
        address token,
        uint256 ceiling,
        uint256 fee
    ) external onlyOwnerExecActivator {
        AssetConfig storage config = assetConfigs[token];
        config.debtCeiling = ceiling;
        config.feePer10k = fee;
    }

    /// Open a new CDP with collateral deposit to a strategy and borrowing
    function mintDepositAndBorrow(
        address collateralToken,
        address strategy,
        uint256 collateralAmount,
        uint256 borrowAmount,
        address recipient
    ) external virtual returns (uint256) {
        uint256 trancheId = _mintTranche(
            msg.sender,
            0,
            strategy,
            collateralToken,
            0,
            collateralAmount
        );
        _borrow(trancheId, borrowAmount, recipient);
        return trancheId;
    }

    /// Deposit collateral to an existing tranche and borrow
    function depositAndBorrow(
        uint256 trancheId,
        uint256 collateralAmount,
        uint256 borrowAmount,
        address recipient
    ) external virtual {
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to withdraw yield"
        );

        if (collateralAmount > 0) {
            _deposit(msg.sender, trancheId, collateralAmount);
        }
        _borrow(trancheId, borrowAmount, recipient);
    }

    /// Borrow stablecoin, taking minting fee and checking viability
    /// (whether balance is above target collateralization)
    /// Disburses any yield in excess of debt to user
    function _borrow(
        uint256 trancheId,
        uint256 borrowAmount,
        address recipient
    ) internal {
        if (borrowAmount > 0) {
            address holdingStrategy = getCurrentHoldingStrategy(trancheId);
            address token = IStrategy(holdingStrategy).trancheToken(trancheId);
            uint256 fee = mintingFee(borrowAmount, token);

            trancheDebt[trancheId] += borrowAmount + fee;

            AssetConfig storage assetConfig = assetConfigs[token];
            assetConfig.totalDebt += borrowAmount + fee;
            require(
                assetConfig.debtCeiling >= assetConfig.totalDebt,
                "Exceeded debt ceiling"
            );
            pendingFees += fee;

            uint256 excessYield = _yieldAndViability(trancheId);
            _mintStable(recipient, borrowAmount + excessYield);
        }
    }

    /// Check viability by requesting valuation of collateral from oracle
    /// and comparing collateral / loan to borrowable threshold (~colRatio)
    /// If a user has earned more yield than they are borrowing, return amount
    function _yieldAndViability(uint256 trancheId)
        internal
        returns (uint256 excessYield)
    {
        uint256 debt = trancheDebt[trancheId];
        address stable = address(stableCoin());

        // As this is a call to the tranche superclass internal function,
        // the 'value' returned is the collateral value, not residual
        (
            uint256 yield,
            uint256 cValue,
            uint256 borrowablePer10k
        ) = _collectYieldValueBorrowable(
                trancheId,
                stable,
                stable,
                address(this)
            );
        require(
            _isViable(debt, yield, cValue, borrowablePer10k),
            "Borow breaks min collateralization threshold"
        );

        if (yield > debt) {
            trancheDebt[trancheId] = 0;
            excessYield = yield - debt;
        } else {
            trancheDebt[trancheId] = debt - yield;
            excessYield = 0;
        }
        _burnStable(address(this), yield);
    }

    /// Repay loan and withdraw collateral
    function repayAndWithdraw(
        uint256 trancheId,
        uint256 collateralAmount,
        uint256 repayAmount,
        address recipient
    ) external virtual {
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to withdraw yield"
        );

        repayAmount = min(repayAmount, trancheDebt[trancheId]);
        _repay(msg.sender, trancheId, repayAmount);
        _withdraw(trancheId, collateralAmount, recipient);
    }

    /// Reimburse collateral, checking viability afterwards
    function _withdraw(
        uint256 trancheId,
        uint256 tokenAmount,
        address recipient
    ) internal virtual override {
        if (tokenAmount > 0) {
            uint256 excessYield = _yieldAndViability(trancheId);
            if (excessYield > 0) {
                _mintStable(recipient, excessYield);
            }
            super._withdraw(trancheId, tokenAmount, recipient);
        }
    }

    /// Extinguish debt from payer wallet balance
    function _repay(
        address payer,
        uint256 trancheId,
        uint256 repayAmount
    ) internal virtual {
        if (repayAmount > 0) {
            _burnStable(payer, repayAmount);
            trancheDebt[trancheId] -= repayAmount;
        }
    }

    /// Check whether a token is accepted as collateral
    function _checkAssetToken(address token) internal view virtual override {
        require(
            assetConfigs[token].debtCeiling > 0,
            "Token is not whitelisted"
        );
    }

    /// Check whether CDP conforms to target collateralization ratio
    /// using borrowable here allows for uninitialized assets to be deposited
    /// but not borrowed against
    function _isViable(
        uint256 debt,
        uint256 yield,
        uint256 collateralValue,
        uint256 borrowablePer10k
    ) internal pure returns (bool) {
        // value / debt > 100% / borrowable%
        return (collateralValue + yield) * borrowablePer10k >= debt * 10_000;
    }

    /// Check CDP against target colRatio
    /// give a pass on very small positions
    function isViable(uint256 trancheId)
        public
        view
        virtual
        override
        returns (bool)
    {
        uint256 debt = trancheDebt[trancheId];
        // allow for tiny amounts of dust
        if (debt < 10_000) {
            return super.isViable(trancheId);
        } else {
            address stable = address(stableCoin());
            (
                uint256 yield,
                uint256 cValue,
                uint256 borrowablePer10k
            ) = viewYieldCollateralValueBorrowable(trancheId, stable, stable);
            bool collateralized = (cValue > debt &&
                0.5 ether > debt &&
                borrowablePer10k > 0) ||
                _isViable(
                    trancheDebt[trancheId],
                    yield,
                    cValue,
                    borrowablePer10k
                );
            return collateralized && super.isViable(trancheId);
        }
    }

    /// Minting fee per stable amount
    function mintingFee(uint256 stableAmount, address collateral)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 feePer10k = assetConfigs[collateral].feePer10k;
        if (feePer10k > 0) {
            return (feePer10k * stableAmount) / 10_000;
        } else {
            return (assetConfigs[address(0)].feePer10k * stableAmount) / 10_000;
        }
    }

    /// Disburse minting fee to feeRecipient
    function withdrawFees() external {
        _mintStable(feeRecipient(), pendingFees);
        pendingFees = 0;
    }

    /// Endpoint for liquidators to liquidate accounts
    function liquidateTo(
        uint256 trancheId,
        address recipient,
        bytes calldata _data
    ) external {
        require(isLiquidator(msg.sender), "Not authorized to liquidate");
        _safeTransfer(ownerOf(trancheId), recipient, trancheId, _data);
    }

    struct ILMetadata {
        uint256 debtCeiling;
        uint256 totalDebt;
        uint256 mintingFee;
        uint256 borrowablePer10k;
    }

    /// View lending metadata for an asset as a whole
    function viewILMetadata(address token)
        public
        view
        returns (ILMetadata memory)
    {
        AssetConfig storage assetConfig = assetConfigs[token];
        (, uint256 borrowablePer10k) = _viewValueBorrowable(
            token,
            0,
            address(stableCoin())
        );
        return
            ILMetadata({
                debtCeiling: assetConfig.debtCeiling,
                totalDebt: assetConfig.totalDebt,
                mintingFee: assetConfig.feePer10k,
                borrowablePer10k: borrowablePer10k
            });
    }

    /// View all lending metadata for all assets
    function viewAllILMetadata(address[] calldata tokens)
        public
        view
        returns (ILMetadata[] memory)
    {
        ILMetadata[] memory result = new ILMetadata[](tokens.length);
        for (uint256 i; tokens.length > i; i++) {
            result[i] = viewILMetadata(tokens[i]);
        }

        return result;
    }

    struct ILStrategyMetadata {
        uint256 debtCeiling;
        uint256 totalDebt;
        uint256 stabilityFee;
        uint256 mintingFee;
        address strategy;
        address token;
        uint256 APF;
        uint256 totalCollateral;
        uint256 borrowablePer10k;
        uint256 valuePer1e18;
        bytes32 strategyName;
        uint256 tvl;
        uint256 harvestBalance2Tally;
        IStrategy.YieldType yieldType;
    }

    /// View an amalgamation of all lending and all strategy metadata
    function viewAllStrategyMetadata()
        public
        view
        returns (ILStrategyMetadata[] memory)
    {
        IStrategy.StrategyMetadata[] memory stratMeta = strategyRegistry()
            .viewAllEnabledStrategyMetadata();

        ILStrategyMetadata[] memory result = new ILStrategyMetadata[](
            stratMeta.length
        );

        for (uint256 i; result.length > i; i++) {
            ILStrategyMetadata memory meta = result[i];
            IStrategy.StrategyMetadata memory sMeta = stratMeta[i];
            ILMetadata memory ilMeta = viewILMetadata(sMeta.token);

            meta.debtCeiling = ilMeta.debtCeiling;
            meta.totalDebt = ilMeta.totalDebt;
            meta.mintingFee = ilMeta.mintingFee;

            meta.strategy = sMeta.strategy;
            meta.token = sMeta.token;
            meta.APF = sMeta.APF;
            meta.totalCollateral = sMeta.totalCollateral;
            meta.borrowablePer10k = sMeta.borrowablePer10k;
            meta.valuePer1e18 = sMeta.valuePer1e18;
            meta.strategyName = sMeta.strategyName;

            meta.tvl = sMeta.tvl;
            meta.harvestBalance2Tally = sMeta.harvestBalance2Tally;
            meta.yieldType = sMeta.yieldType;
            meta.stabilityFee = sMeta.stabilityFee;
        }

        return result;
    }

    struct PositionMetadata {
        uint256 trancheId;
        address strategy;
        uint256 collateral;
        uint256 debt;
        address token;
        uint256 yield;
        uint256 collateralValue;
        uint256 borrowablePer10k;
    }

    /// View the metadata for all the positions held by an address
    function viewPositionsByOwner(address owner)
        external
        view
        returns (PositionMetadata[] memory)
    {
        uint256[] memory trancheIds = viewTranchesByOwner(owner);
        PositionMetadata[] memory result = new PositionMetadata[](
            trancheIds.length
        );
        for (uint256 i; trancheIds.length > i; i++) {
            uint256 _trancheId = trancheIds[i];
            result[i] = viewPositionMetadata(_trancheId);
        }

        return result;
    }

    /// View metadata for one position
    function viewPositionMetadata(uint256 _trancheId)
        public
        view
        returns (PositionMetadata memory)
    {
        address holdingStrategy = _holdingStrategies[_trancheId];

        (
            uint256 yield,
            uint256 cValue,
            uint256 borrowablePer10k
        ) = viewYieldCollateralValueBorrowable(
                _trancheId,
                address(stableCoin()),
                address(stableCoin())
            );

        return
            PositionMetadata({
                trancheId: _trancheId,
                strategy: holdingStrategy,
                token: IStrategy(holdingStrategy).trancheToken(_trancheId),
                collateral: IStrategy(holdingStrategy)
                    .viewTargetCollateralAmount(_trancheId),
                debt: trancheDebt[_trancheId],
                yield: yield,
                collateralValue: cValue,
                borrowablePer10k: borrowablePer10k
            });
    }

    /// Value restricted to collateral value
    function viewYieldCollateralValueBorrowable(
        uint256 trancheId,
        address yieldCurrency,
        address valueCurrency
    )
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return
            super.viewYieldValueBorrowable(
                trancheId,
                yieldCurrency,
                valueCurrency
            );
    }

    /// View collateral value
    function viewCollateralValue(uint256 trancheId, address valueCurrency)
        public
        view
        returns (uint256)
    {
        return
            IStrategy(_holdingStrategies[trancheId]).viewValue(
                trancheId,
                valueCurrency
            );
    }

    /// View collateral value in our stable
    function viewCollateralValue(uint256 trancheId)
        external
        view
        returns (uint256)
    {
        return viewCollateralValue(trancheId, address(stableCoin()));
    }

    /// View yield value and borrowable together
    function viewYieldValueBorrowable(
        uint256 trancheId,
        address yieldCurrency,
        address valueCurrency
    )
        public
        view
        override
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 yield, uint256 cValue, uint256 borrowablePer10k) = super
            .viewYieldValueBorrowable(trancheId, yieldCurrency, valueCurrency);

        uint256 debt = trancheDebt[trancheId];

        return (yield, cValue > debt ? cValue - debt : 0, borrowablePer10k);
    }

    /// Collateral amount in tranche
    function viewTargetCollateralAmount(uint256 trancheId)
        external
        view
        returns (uint256)
    {
        return
            IStrategy(_holdingStrategies[trancheId]).viewTargetCollateralAmount(
                trancheId
            );
    }

    /// Collect yield and view value and borrowable per 10k
    function collectYieldValueBorrowable(
        uint256 trancheId,
        address yieldCurrency,
        address valueCurrency,
        address recipient
    )
        public
        virtual
        override
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(
            isAuthorized(msg.sender, trancheId) || isFundTransferer(msg.sender),
            "not authorized to withdraw yield"
        );
        (
            uint256 yield,
            uint256 cValue,
            uint256 borrowablePer10k
        ) = _collectYieldValueBorrowable(
                trancheId,
                yieldCurrency,
                valueCurrency,
                recipient
            );

        uint256 debt = trancheDebt[trancheId];
        return (yield, cValue > debt ? cValue - debt : 0, borrowablePer10k);
    }

    /// Minimum of two numbers
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return b;
        } else {
            return a;
        }
    }
}
