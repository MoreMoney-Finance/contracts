// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./ProxyOwnershipERC721.sol";
import "./roles/RoleAware.sol";
import "./StrategyRegistry.sol";
import "./TrancheIDService.sol";
import "./roles/DependsOnTrancheIDService.sol";
import "./roles/DependsOnStrategyRegistry.sol";
import "./roles/DependsOnFundTransferer.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./royalties/ERC2981.sol";

/// Express an amount of token held in yield farming strategy as an ERC721
contract Tranche is
    ProxyOwnershipERC721,
    DependsOnTrancheIDService,
    DependsOnStrategyRegistry,
    DependsOnFundTransferer,
    RoleAware,
    IAsset,
    ReentrancyGuard,
    ERC2981
{
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;

    event TrancheUpdated(uint256 indexed trancheId);

    mapping(uint256 => address) public _holdingStrategies;

    mapping(uint256 => EnumerableSet.UintSet) internal updatedTranches;
    uint256 public updateTrackingPeriod = 7 days;

    constructor(
        string memory _name,
        string memory _symbol,
        address _roles
    ) ERC721(_name, _symbol) RoleAware(_roles) {
        _rolesPlayed.push(TRANCHE);
        _setDefaultRoyalty(Roles(_roles).mainCharacters(FEE_RECIPIENT), 100);
    }

    /// internal function managing the minting of new tranches
    /// letting the holding strategy collect the asset
    function _mintTranche(
        address minter,
        uint256 vaultId,
        address strategy,
        address assetToken,
        uint256 assetTokenId,
        uint256 assetAmount
    ) internal returns (uint256 trancheId) {
        require(
            strategyRegistry().enabledStrategy(strategy),
            "Strategy not approved"
        );

        trancheId = trancheIdService().getNextTrancheId();

        _holdingStrategies[trancheId] = strategy;
        _containedIn[trancheId] = vaultId;
        _checkAssetToken(assetToken);
        _safeMint(minter, trancheId, abi.encode(vaultId));

        IStrategy(strategy).registerMintTranche(
            minter,
            trancheId,
            assetToken,
            assetTokenId,
            assetAmount
        );

        _trackUpdated(trancheId);
    }

    /// Mint a new tranche
    function mintTranche(
        uint256 vaultId,
        address strategy,
        address assetToken,
        uint256 assetTokenId,
        uint256 assetAmount
    ) external nonReentrant returns (uint256 trancheId) {
        return
            _mintTranche(
                msg.sender,
                vaultId,
                strategy,
                assetToken,
                assetTokenId,
                assetAmount
            );
    }

    /// Deposit more collateral to the tranche
    function deposit(uint256 trancheId, uint256 tokenAmount)
        external
        nonReentrant
    {
        _deposit(msg.sender, trancheId, tokenAmount);
    }

    /// Endpoint for authorized fund transferer to deposit on behalf of user
    function registerDepositFor(
        address depositor,
        uint256 trancheId,
        uint256 tokenAmount
    ) external {
        require(isFundTransferer(msg.sender), "Unauthorized fund transfer");
        _deposit(depositor, trancheId, tokenAmount);
    }

    /// Internal logic for depositing
    function _deposit(
        address depositor,
        uint256 trancheId,
        uint256 tokenAmount
    ) internal virtual {
        IStrategy strat = IStrategy(getCurrentHoldingStrategy(trancheId));
        strat.registerDepositFor(
            depositor,
            trancheId,
            tokenAmount,
            ownerOf(trancheId)
        );
        _trackUpdated(trancheId);
    }

    /// Withdraw tokens from tranche, checing viability
    function withdraw(
        uint256 trancheId,
        uint256 tokenAmount,
        address yieldCurrency,
        address recipient
    ) external override nonReentrant {
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to withdraw"
        );
        require(recipient != address(0), "Don't burn");

        _withdraw(trancheId, tokenAmount, yieldCurrency, recipient);
    }

    /// Withdraw tokens from tranche, checing viability, internal logic
    function _withdraw(
        uint256 trancheId,
        uint256 tokenAmount,
        address yieldCurrency,
        address recipient
    ) internal virtual {
        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
        IStrategy(holdingStrategy).withdraw(
            trancheId,
            tokenAmount,
            yieldCurrency,
            recipient
        );
        require(isViable(trancheId), "Tranche unviable");
        _trackUpdated(trancheId);
    }

    /// Make strategy calculate and disburse yield
    function _collectYield(
        uint256 trancheId,
        address currency,
        address recipient
    ) internal returns (uint256) {
        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
        uint256 yield = IStrategy(holdingStrategy).collectYield(
            trancheId,
            currency,
            recipient
        );

        _trackUpdated(trancheId);
        return yield;
    }

    /// Disburse yield in tranche to recipient
    function collectYield(
        uint256 trancheId,
        address currency,
        address recipient
    ) external virtual override nonReentrant returns (uint256) {
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to withdraw yield"
        );
        return _collectYield(trancheId, currency, recipient);
    }

    /// Collect yield in a batch
    function batchCollectYield(
        uint256[] calldata trancheIds,
        address currency,
        address recipient
    ) external nonReentrant returns (uint256) {
        uint256 yield;

        for (uint256 i; trancheIds.length > i; i++) {
            uint256 trancheId = trancheIds[i];
            require(
                isAuthorized(msg.sender, trancheId),
                "not authorized to withdraw"
            );

            yield += _collectYield(trancheId, currency, recipient);
        }
        return yield;
    }

    /// View accrued yield in a tranche
    function viewYield(uint256 trancheId, address currency)
        public
        view
        virtual
        override
        returns (uint256)
    {
        address holdingStrategy = _holdingStrategies[trancheId];
        return IStrategy(holdingStrategy).viewYield(trancheId, currency);
    }

    /// View yield jointly in a batch
    function batchViewYield(uint256[] calldata trancheIds, address currency)
        public
        view
        returns (uint256)
    {
        uint256 yield;

        for (uint256 i; trancheIds.length > i; i++) {
            uint256 trancheId = trancheIds[i];

            yield += viewYield(trancheId, currency);
        }
        return yield;
    }

    /// View borrowable per 10k of tranche
    function viewBorrowable(uint256 trancheId)
        public
        view
        override
        returns (uint256)
    {
        address holdingStrategy = _holdingStrategies[trancheId];
        return IStrategy(holdingStrategy).viewBorrowable(trancheId);
    }

    /// View value, and borrowable (average weighted by value) for a batch, jointly
    function batchViewValueBorrowable(
        uint256[] calldata trancheIds,
        address currency
    ) public view returns (uint256, uint256) {
        uint256 totalValue;
        uint256 totalBorrowablePer10k;
        for (uint256 i; trancheIds.length > i; i++) {
            uint256 trancheId = trancheIds[i];

            (uint256 value, uint256 borrowablePer10k) = IStrategy(
                _holdingStrategies[trancheId]
            ).viewValueBorrowable(trancheId, currency);
            totalBorrowablePer10k += value * borrowablePer10k;
        }

        return (totalValue, totalBorrowablePer10k / totalValue);
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
        require(
            isAuthorized(msg.sender, trancheId) || isFundTransferer(msg.sender),
            "not authorized to withdraw"
        );
        return
            _collectYieldValueBorrowable(
                trancheId,
                yieldCurrency,
                valueCurrency,
                recipient
            );
    }

    /// Internal function to collect yield and view value and borrowable per 10k
    function _collectYieldValueBorrowable(
        uint256 trancheId,
        address yieldCurrency,
        address valueCurrency,
        address recipient
    )
        internal
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
        return
            IStrategy(holdingStrategy).collectYieldValueBorrowable(
                trancheId,
                yieldCurrency,
                valueCurrency,
                recipient
            );
    }

    /// Collect yield and view value and borrowable jointly and in weighted avg.
    function batchCollectYieldValueBorrowable(
        uint256[] calldata trancheIds,
        address yieldCurrency,
        address valueCurrency,
        address recipient
    )
        public
        returns (
            uint256 yield,
            uint256 value,
            uint256 borrowablePer10k
        )
    {
        for (uint256 i; trancheIds.length > i; i++) {
            uint256 trancheId = trancheIds[i];

            // these calls are nonReentrant individually
            (
                uint256 _yield,
                uint256 _value,
                uint256 _borrowablePer10k
            ) = collectYieldValueBorrowable(
                    trancheId,
                    yieldCurrency,
                    valueCurrency,
                    recipient
                );
            yield += _yield;
            value += _value;
            borrowablePer10k += _borrowablePer10k * _value;
        }
        borrowablePer10k = borrowablePer10k / value;
    }

    /// View yield value and borrowable together
    function viewYieldValueBorrowable(
        uint256 trancheId,
        address yieldCurrency,
        address valueCurrency
    )
        public
        view
        virtual
        override
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        address holdingStrategy = _holdingStrategies[trancheId];
        return
            IStrategy(holdingStrategy).viewYieldValueBorrowable(
                trancheId,
                yieldCurrency,
                valueCurrency
            );
    }

    /// Check if a tranche is viable. Can be overriden to check
    /// collateralization ratio. By default defer to container.
    function isViable(uint256 trancheId)
        public
        view
        virtual
        override
        returns (bool)
    {
        address tokenOwner = ownerOf(trancheId);
        if (tokenOwner.isContract()) {
            IProxyOwnership bearer = IProxyOwnership(tokenOwner);
            return bearer.isViable(_containedIn[trancheId]);
        } else {
            return true;
        }
    }

    /// Migrate assets from one strategy to another, collecting yield if any
    function migrateStrategy(
        uint256 trancheId,
        address destination,
        address yieldToken,
        address yieldRecipient
    )
        external
        override
        nonReentrant
        returns (
            address token,
            uint256 tokenId,
            uint256 targetAmount
        )
    {
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to migrate"
        );

        require(
            strategyRegistry().enabledStrategy(destination),
            "Strategy not approved"
        );

        address sourceStrategy = getCurrentHoldingStrategy(trancheId);
        (token, tokenId, targetAmount) = IStrategy(sourceStrategy)
            .migrateStrategy(
                trancheId,
                destination,
                yieldToken,
                yieldRecipient
            );

        _acceptStrategyMigration(
            trancheId,
            sourceStrategy,
            destination,
            token,
            tokenId,
            targetAmount
        );

        _trackUpdated(trancheId);
    }

    /// Notify a recipient strategy that they have been migrated to
    function _acceptStrategyMigration(
        uint256 trancheId,
        address tokenSource,
        address destination,
        address token,
        uint256 tokenId,
        uint256 targetAmount
    ) internal {
        IStrategy(destination).acceptMigration(
            trancheId,
            tokenSource,
            token,
            tokenId,
            targetAmount
        );

        _holdingStrategies[trancheId] = destination;
    }

    /// Retrieve current strategy and update if necessary
    function getCurrentHoldingStrategy(uint256 trancheId)
        public
        returns (address)
    {
        address oldStrat = _holdingStrategies[trancheId];
        StrategyRegistry registry = strategyRegistry();
        address newStrat = registry.getCurrentStrategy(oldStrat);

        if (oldStrat != newStrat) {
            _acceptStrategyMigration(
                trancheId,
                address(registry),
                newStrat,
                IStrategy(oldStrat).trancheToken(trancheId),
                IStrategy(oldStrat).trancheTokenID(trancheId),
                IStrategy(oldStrat).viewTargetCollateralAmount(trancheId)
            );
        }

        return newStrat;
    }

    /// View which strategy should be holding assets for a tranche,
    /// taking into account global migrations
    function viewCurrentHoldingStrategy(uint256 trancheId)
        public
        view
        returns (address)
    {
        return
            StrategyRegistry(strategyRegistry()).getCurrentStrategy(
                _holdingStrategies[trancheId]
            );
    }

    /// Internals of tranche transfer, correctly tracking containement
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal override {
        super._safeTransfer(from, to, tokenId, _data);
        if (_data.length > 0) {
            _containedIn[tokenId] = abi.decode(_data, (uint256));
        }

        _trackUpdated(tokenId);
    }

    /// Set up an ID slot for this tranche with the id service
    function setupTrancheSlot() external {
        trancheIdService().setupTrancheSlot();
    }

    /// Check whether an asset token is admissible
    function _checkAssetToken(address token) internal view virtual {}

    /// View all the tranches of an owner
    function viewTranchesByOwner(address owner)
        public
        view
        virtual
        returns (uint256[] memory)
    {
        uint256 num = balanceOf(owner);
        uint256[] memory result = new uint256[](num);
        for (uint256 i; num > i; i++) {
            result[i] = tokenOfOwnerByIndex(owner, i);
        }

        return result;
    }

    function trancheToken(uint256 trancheId) external view returns (address) {
        return
            IStrategy(viewCurrentHoldingStrategy(trancheId)).trancheToken(
                trancheId
            );
    }

    /// track that a tranche was updated
    function _trackUpdated(uint256 trancheId) internal {
        updatedTranches[block.timestamp / updateTrackingPeriod].add(trancheId);
        emit TrancheUpdated(trancheId);
    }

    /// Set update tracking period
    function setUpdateTrackingPeriod(uint256 period) external onlyOwnerExec {
        require(period != 0, "Period can't be zero");
        updateTrackingPeriod = period;

        emit ParameterUpdated("tracking period", period);
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// set the default royalty
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwnerExec {
        _setDefaultRoyalty(receiver, feeNumerator);
    }
}