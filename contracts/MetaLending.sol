// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./roles/RoleAware.sol";
import "./Tranche.sol";
import "./roles/CallsStableCoinMintBurn.sol";
import "./roles/DependsOnFeeRecipient.sol";
import "./roles/DependsOnInterestRateController.sol";
import "./oracles/OracleAware.sol";
import "../interfaces/IFeeReporter.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// Centerpiece of CDP: lending minted stablecoin against collateral
/// Collateralized debt positions are expressed as ERC721 tokens (via Tranche)
contract MetaLending is
    OracleAware,
    Tranche,
    CallsStableCoinMintBurn,
    DependsOnFeeRecipient,
    DependsOnInterestRateController,
    IFeeReporter
{
    using EnumerableSet for EnumerableSet.UintSet;
    struct AssetConfig {
        uint256 debtCeiling;
        uint256 feePer10k;
        uint256 totalDebt;
        uint256 compoundStart;
    }
    using Strings for uint256;

    string public baseURI = "https://static.moremoney.finance/";

    mapping(address => AssetConfig) public assetConfigs;

    mapping(uint256 => uint256) public _trancheDebt;
    mapping(uint256 => uint256) public compoundStart;

    uint256 public totalDebt;
    uint256 public totalEarnedInterest;
    uint256 public compoundPer1e18 = 1e18;
    uint256 public compoundLastUpdated;
    uint256 public compoundWindow = 6 hours;

    uint256 public pendingFees;
    uint256 public pastFees;

    constructor(address _roles)
        Tranche("Moremoney Meta Lending", "MMML", _roles)
    {
        _charactersPlayed.push(META_LENDING);
        _rolesPlayed.push(FUND_TRANSFERER);
        updateTrackingPeriod = 12 hours;
        compoundLastUpdated = block.timestamp;
    }

    function concat(bytes memory a, bytes memory b)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(a, b);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );

        string memory _tokenURI = string(concat(bytes(baseURI), bytes(Strings.toString(tokenId))));
        return _tokenURI;
    }

    /// Set the debt ceiling for an asset
    function setAssetDebtCeiling(address token, uint256 ceiling)
        external
        onlyOwnerExec
    {
        assetConfigs[token].debtCeiling = ceiling;
        emit SubjectParameterUpdated("asset debt ceil", token, ceiling);
    }

    /// Set minting fee per an asset
    function setFeesPer10k(address token, uint256 fee) external onlyOwnerExec {
        assetConfigs[token].feePer10k = fee;
        emit SubjectParameterUpdated("fees per 10k", token, fee);
    }

    /// Open a new CDP with collateral deposit to a strategy and borrowing
    function mintDepositAndBorrow(
        address collateralToken,
        address strategy,
        uint256 collateralAmount,
        uint256 borrowAmount,
        address stableRecipient
    ) external virtual nonReentrant returns (uint256) {
        uint256 trancheId = _mintTranche(
            msg.sender,
            0,
            strategy,
            collateralToken,
            0,
            collateralAmount
        );
        _borrow(trancheId, borrowAmount, stableRecipient);
        return trancheId;
    }

    /// Deposit collateral to an existing tranche and borrow
    function depositAndBorrow(
        uint256 trancheId,
        uint256 collateralAmount,
        uint256 borrowAmount,
        address recipient
    ) external virtual nonReentrant {
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to withdraw"
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
        updateTrancheDebt(trancheId);
        if (borrowAmount > 0) {
            address holdingStrategy = getCurrentHoldingStrategy(trancheId);
            address token = IStrategy(holdingStrategy).trancheToken(trancheId);

            uint256 feePer10k = assetConfigs[token].feePer10k;
            uint256 fee = (feePer10k * borrowAmount) / 10_000;

            _trancheDebt[trancheId] += borrowAmount + fee;

            updateAssetTotalDebt(token);
            AssetConfig storage assetConfig = assetConfigs[token];
            assetConfig.totalDebt += borrowAmount + fee;
            totalDebt += borrowAmount + fee;
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
        // this only gets called in contexts where updateTrancheDebt has already been called
        uint256 debt = _trancheDebt[trancheId];
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
            "Borow breaks min colratio"
        );

        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
        address token = IStrategy(holdingStrategy).trancheToken(trancheId);
        
        updateAssetTotalDebt(token);
        if (yield > debt) {
            _trancheDebt[trancheId] = 0;
            excessYield = yield - debt;
            assetConfigs[token].totalDebt -= debt;
            totalDebt -= debt;
        } else {
            _trancheDebt[trancheId] = debt - yield;
            excessYield = 0;
            assetConfigs[token].totalDebt -= yield;
            totalDebt -= yield;
        }
        if (yield > 0) {
            _burnStable(address(this), yield);
        }
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
            "not authorized to withdraw"
        );

        uint256 debt = trancheDebt(trancheId);
        repayAmount = min(repayAmount, debt);
        _repay(msg.sender, trancheId, repayAmount);
        _withdraw(
            trancheId,
            collateralAmount,
            address(stableCoin()),
            recipient
        );
    }

    /// Only repay a loan
    function repay(uint256 trancheId, uint256 repayAmount) external virtual {
        repayAmount = min(repayAmount, trancheDebt(trancheId));
        _repay(msg.sender, trancheId, repayAmount);
    }

    /// Reimburse collateral, checking viability afterwards
    function _withdraw(
        uint256 trancheId,
        uint256 tokenAmount,
        address yieldCurrency,
        address recipient
    ) internal virtual override {
        updateTrancheDebt(trancheId);
        if (tokenAmount > 0) {
            uint256 excessYield = _yieldAndViability(trancheId);
            if (excessYield > 0) {
                _mintStable(recipient, excessYield);
            }
            super._withdraw(trancheId, tokenAmount, yieldCurrency, recipient);
        }
    }

    /// Extinguish debt from payer wallet balance
    function _repay(
        address payer,
        uint256 trancheId,
        uint256 repayAmount
    ) internal virtual {
        updateTrancheDebt(trancheId);
        if (repayAmount > 0) {
            _burnStable(payer, repayAmount);
            _trancheDebt[trancheId] -= repayAmount;
            address holdingStrategy = getCurrentHoldingStrategy(trancheId);
            address token = IStrategy(holdingStrategy).trancheToken(trancheId);

            updateAssetTotalDebt(token);
            AssetConfig storage assetConfig = assetConfigs[token];
            assetConfig.totalDebt -= repayAmount;
            totalDebt -= repayAmount;
        }
    }

    /// Check whether a token is accepted as collateral
    function _checkAssetToken(address token) internal view virtual override {
        require(assetConfigs[token].debtCeiling > 0, "Token not whitelisted");
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
        uint256 debt = trancheDebt(trancheId);
        // allow for tiny amounts of dust
        if (debt < 1e12) {
            return super.isViable(trancheId);
        } else {
            address stable = address(stableCoin());
            (
                uint256 yield,
                uint256 cValue,
                uint256 borrowablePer10k
            ) = viewYieldCollateralValueBorrowable(trancheId, stable, stable);
            bool collateralized = (cValue > debt &&
                0.3 ether > debt &&
                borrowablePer10k > 0) ||
                _isViable(debt, yield, cValue, borrowablePer10k);
            return collateralized && super.isViable(trancheId);
        }
    }

    /// Disburse minting fee to feeRecipient
    function withdrawFees() external {
        _mintStable(feeRecipient(), pendingFees);
        pastFees += pendingFees;
        pendingFees = 0;
    }

    /// All fees ever
    function viewAllFeesEver() external view override returns (uint256) {
        return pastFees + pendingFees;
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
        address underlyingStrategy;
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
        address owner;
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
                debt: trancheDebt(_trancheId),
                yield: yield,
                collateralValue: cValue,
                borrowablePer10k: borrowablePer10k,
                owner: ownerOf(_trancheId)
            });
    }

    /// View the metadata for all positions updated in a timeframe
    function viewPositionsByTrackingPeriod(uint256 trackingPeriod)
        public
        view
        returns (PositionMetadata[] memory rows)
    {
        EnumerableSet.UintSet storage trancheSet = updatedTranches[
            trackingPeriod
        ];
        uint256 len = trancheSet.length();

        rows = new PositionMetadata[](len);
        for (uint256 i; len > i; i++) {
            rows[i] = viewPositionMetadata(trancheSet.at(i));
        }
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

        uint256 debt = trancheDebt(trancheId);

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
        nonReentrant
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        updateTrancheDebt(trancheId);
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to withdraw"
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

        uint256 debt = _trancheDebt[trancheId];
        return (yield, cValue > debt ? cValue - debt : 0, borrowablePer10k);
    }

    function viewUpdatedCompound() public view returns (uint256) {
        if (block.timestamp > compoundLastUpdated + compoundWindow) {
            uint256 rate = interestRateController().currentRatePer10k();
            uint256 timeDelta = block.timestamp - compoundLastUpdated;

            return
                compoundPer1e18 +
                (compoundPer1e18 * rate * timeDelta) /
                (365 days) /
                10_000;
        } else {
            return compoundPer1e18;
        }
    }

    function updateCompound() internal returns (uint256) {
        interestRateController().updateRate();
        uint256 updatedCompound = viewUpdatedCompound();
        if (updatedCompound > compoundPer1e18) {
            uint256 oldTotalDebt = totalDebt;
            totalDebt = (oldTotalDebt * updatedCompound) / compoundPer1e18;
            totalEarnedInterest += totalDebt - oldTotalDebt;

            compoundPer1e18 = updatedCompound;
            compoundLastUpdated = block.timestamp;
        }
        return updatedCompound;
    }

    function updateTrancheDebt(uint256 trancheId) internal {
        uint256 compound = updateCompound();
        uint256 start = compoundStart[trancheId];
        if (start > 0) {
            _trancheDebt[trancheId] =
                (_trancheDebt[trancheId] * compound) /
                start;
        }
        compoundStart[trancheId] = compound;
    }

    function updateAssetTotalDebt(address token) internal {
        uint256 compound = updateCompound();
        AssetConfig storage assetConfig = assetConfigs[token];
        uint256 start = assetConfig.compoundStart;
        if (start > 0) {
            assetConfig.totalDebt = assetConfig.totalDebt * compound / start;
        }
        assetConfig.compoundStart = compound;
    }

    function trancheDebt(uint256 trancheId) public view returns (uint256) {
        uint256 compound = viewUpdatedCompound();
        uint256 start = compoundStart[trancheId];
        if (start > 0) {
            return (_trancheDebt[trancheId] * compound) / start;
        } else {
            return _trancheDebt[trancheId];
        }
    }

    function setCompoundWindow(uint256 window) external onlyOwnerExec {
        compoundWindow = window;
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
