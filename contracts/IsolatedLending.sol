// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./roles/RoleAware.sol";
import "./Tranche.sol";
import "./roles/CallsStableCoinMintBurn.sol";
import "./roles/DependsOnLiquidator.sol";
import "./roles/DependsOnFeeRecipient.sol";

contract IsolatedLending is
    Tranche,
    CallsStableCoinMintBurn,
    DependsOnLiquidator,
    DependsOnFeeRecipient
{
    struct AssetConfig {
        uint256 debtCeiling;
        uint256 feePerMil;
        uint256 totalDebt;
    }
    mapping(address => AssetConfig) public assetConfigs;

    uint256 public liqRatioConversionFactor = 8;

    mapping(uint256 => uint256) public trancheDebt;
    uint256 public pendingFees;

    constructor(address _roles)
        Tranche("MoreMoney Isolated Lending", "MMIL", _roles)
    {
        _charactersPlayed.push(ISOLATED_LENDING);
    }

    function setAssetDebtCeiling(address token, uint256 ceiling)
        external
        onlyOwnerExecDisabler
    {
        assetConfigs[token].debtCeiling = ceiling;
    }

    function setFeesPerMil(address token, uint256 fee) external onlyOwnerExec {
        assetConfigs[token].feePerMil = fee;
    }

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

        _deposit(msg.sender, trancheId, collateralAmount);
        _borrow(trancheId, borrowAmount, recipient);
    }

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

    function _yieldAndViability(uint256 trancheId)
        internal
        returns (uint256 excessYield)
    {
        uint256 debt = trancheDebt[trancheId];
        address stable = address(stableCoin());
        (
            uint256 yield,
            uint256 value,
            uint256 colRatio
        ) = _collectYieldValueColRatio(
                trancheId,
                stable,
                stable,
                address(this)
            );
        require(
            _isViable(debt, yield, value, colRatio),
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

        _repay(msg.sender, trancheId, repayAmount);
        _withdraw(trancheId, collateralAmount, recipient);
    }

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

    function _checkAssetToken(address token) internal view virtual override {
        require(
            assetConfigs[token].debtCeiling > 0,
            "Token is not whitelisted"
        );
    }

    function _isViable(
        uint256 debt,
        uint256 yield,
        uint256 value,
        uint256 colRatio
    ) internal pure returns (bool) {
        return (value + yield) * 1000 >= debt * colRatio;
    }

    function isViable(uint256 trancheId)
        public
        view
        virtual
        override
        returns (bool)
    {
        address stable = address(stableCoin());
        (
            uint256 yield,
            uint256 value,
            uint256 colRatio
        ) = viewYieldValueColRatio(trancheId, stable, stable);
        bool collateralized = _isViable(
            trancheDebt[trancheId],
            yield,
            value,
            colRatio
        );
        return collateralized && super.isViable(trancheId);
    }

    /// Minting fee per stable amount
    function mintingFee(uint256 stableAmount, address collateral)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 feePerMil = assetConfigs[collateral].feePerMil;
        if (feePerMil > 0) {
            return (feePerMil * stableAmount) / 1000;
        } else {
            return (assetConfigs[address(0)].feePerMil * stableAmount) / 1000;
        }
    }

    function withdrawFees() external {
        _mintStable(feeRecipient(), pendingFees);
        pendingFees = 0;
    }

    function liquidateTo(
        uint256 trancheId,
        address recipient,
        bytes calldata _data
    ) external {
        require(isLiquidator(msg.sender), "Not authorized to liquidate");
        _safeTransfer(ownerOf(trancheId), recipient, trancheId, _data);
    }

    function viewYieldValueColRatioDebt(
        uint256 trancheId,
        address yieldCurrency,
        address valueCurrency
    )
        external
        view
        returns (
            uint256 yield,
            uint256 value,
            uint256 colRatio,
            uint256 debt
        )
    {
        (yield, value, colRatio) = viewYieldValueColRatio(
            trancheId,
            yieldCurrency,
            valueCurrency
        );
        debt = trancheDebt[trancheId];
    }

    struct ILMetadata {
        uint256 debtCeiling;
        uint256 totalDebt;
        uint256 stabilityFee;
        uint256 mintingFee;
    }

    function viewILMetadata(address token) public view returns (ILMetadata memory) {
        AssetConfig storage assetConfig = assetConfigs[token];
        return ILMetadata({
            debtCeiling: assetConfig.debtCeiling,
            totalDebt: assetConfig.totalDebt,
            stabilityFee: 0,
            mintingFee: assetConfig.feePerMil
        });
    }

    function viewAllILMetadata(address[] calldata tokens) public view returns (ILMetadata[] memory) {
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
        uint256 colRatio;
        uint256 valuePer1e18;
        bytes32 strategyName;

        uint256 liqRatio;
    }

    function viewAllStrategyMetadata() public view returns (ILStrategyMetadata[] memory) {
        IStrategy.StrategyMetadata[] memory stratMeta = strategyRegistry().viewAllEnabledStrategyMetadata();

        ILStrategyMetadata[] memory result = new ILStrategyMetadata[](stratMeta.length);

        for (uint i; result.length > i; i++) {
            ILStrategyMetadata memory meta = result[i];
            IStrategy.StrategyMetadata memory sMeta = stratMeta[i];
            ILMetadata memory ilMeta = viewILMetadata(meta.token);

            meta.debtCeiling = ilMeta.debtCeiling;
            meta.totalDebt = ilMeta.totalDebt;
            meta.stabilityFee = ilMeta.stabilityFee;
            meta.mintingFee = ilMeta.mintingFee;

            meta.strategy = sMeta.strategy;
            meta.token = sMeta.token;
            meta.APF = sMeta.APF;
            meta.totalCollateral = sMeta.totalCollateral;
            meta.colRatio = sMeta.colRatio;
            meta.valuePer1e18 = sMeta.valuePer1e18;
            meta.strategyName = sMeta.strategyName;

            meta.liqRatio = colRatio2LiqRatio(sMeta.colRatio);
        }

        return result;
    }

    function colRatio2LiqRatio(uint256 colRatio) public virtual view returns (uint256) {
        if (11_000 >= colRatio) {
            return (10_000 + colRatio) / 2;
        } else {
            return 10_500 + (colRatio - 10_500) / liqRatioConversionFactor;
        }
    }

    function setLiqRatioConversionFactor(uint256 convFactor) external onlyOwnerExec {
        liqRatioConversionFactor = convFactor;
    }
}
