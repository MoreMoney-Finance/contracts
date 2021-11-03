// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./ProxyOwnershipERC721.sol";
import "./roles/RoleAware.sol";
import "./StrategyRegistry.sol";
import "./TrancheIDService.sol";
import "./roles/DependsOnTrancheIDService.sol";
import "./roles/DependsOnStrategyRegistry.sol";
import "./roles/DependsOnFundTransferer.sol";

contract Tranche is
    ProxyOwnershipERC721,
    DependsOnTrancheIDService,
    DependsOnStrategyRegistry,
    DependsOnFundTransferer,
    RoleAware,
    IAsset
{
    using Address for address;

    mapping(uint256 => address) public _holdingStrategies;

    constructor(
        string memory _name,
        string memory _symbol,
        address _roles
    ) ERC721(_name, _symbol) RoleAware(_roles) {
        _rolesPlayed.push(TRANCHE);
    }

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
    }

    function mintTranche(
        uint256 vaultId,
        address strategy,
        address assetToken,
        uint256 assetTokenId,
        uint256 assetAmount
    ) external returns (uint256 trancheId) {
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

    function deposit(uint256 trancheId, uint256 tokenAmount) external override {
        _deposit(msg.sender, trancheId, tokenAmount);
    }

    function registerDepositFor(
        address depositor,
        uint256 trancheId,
        uint256 tokenAmount
    ) external override {
        require(
            isFundTransferer(msg.sender),
            "Not authorized to transfer user funds"
        );
        _deposit(depositor, trancheId, tokenAmount);
    }

    function _deposit(
        address depositor,
        uint256 trancheId,
        uint256 tokenAmount
    ) internal virtual {
        IStrategy(getCurrentHoldingStrategy(trancheId)).registerDepositFor(
            depositor,
            trancheId,
            tokenAmount
        );
    }

    function withdraw(
        uint256 trancheId,
        uint256 tokenAmount,
        address recipient
    ) external override {
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to withdraw"
        );
        _withdraw(trancheId, tokenAmount, recipient);
    }

    function _withdraw(
        uint256 trancheId,
        uint256 tokenAmount,
        address recipient
    ) internal virtual {
        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
        IStrategy(holdingStrategy).withdraw(trancheId, tokenAmount, recipient);

        require(isViable(trancheId), "Tranche not viable after withdraw");
    }

    function burnTranche(
        uint256 trancheId,
        address yieldToken,
        address recipient
    ) external override {
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to withdraw"
        );

        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
        IStrategy(holdingStrategy).burnTranche(
            trancheId,
            yieldToken,
            recipient
        );

        require(isViable(trancheId), "Tranche not viable after withdraw");
    }

    function _collectYield(
        uint256 trancheId,
        address currency,
        address recipient
    ) internal returns (uint256) {
        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
        return
            IStrategy(holdingStrategy).collectYield(
                trancheId,
                currency,
                recipient
            );
    }

    function collectYield(
        uint256 trancheId,
        address currency,
        address recipient
    ) public virtual override returns (uint256) {
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to withdraw yield"
        );
        return _collectYield(trancheId, currency, recipient);
    }

    function batchCollectYield(
        uint256[] calldata trancheIds,
        address currency,
        address recipient
    ) public returns (uint256) {
        uint256 yield;

        for (uint256 i; trancheIds.length > i; i++) {
            uint256 trancheId = trancheIds[i];
            require(
                isAuthorized(msg.sender, trancheId),
                "not authorized to withdraw yield"
            );

            yield += _collectYield(trancheId, currency, recipient);
        }
        return yield;
    }

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

    function viewValue(uint256 trancheId, address currency)
        public
        view
        override
        returns (uint256)
    {
        address holdingStrategy = _holdingStrategies[trancheId];
        return IStrategy(holdingStrategy).viewValue(trancheId, currency);
    }

    function batchViewValue(uint256[] calldata trancheIds, address currency)
        public
        view
        returns (uint256)
    {
        uint256 value;

        for (uint256 i; trancheIds.length > i; i++) {
            uint256 trancheId = trancheIds[i];

            value += viewValue(trancheId, currency);
        }

        return value;
    }

    function viewBorrowable(uint256 trancheId)
        public
        view
        override
        returns (uint256)
    {
        address holdingStrategy = _holdingStrategies[trancheId];
        return IStrategy(holdingStrategy).viewBorrowable(trancheId);
    }

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

    function collectYieldValueBorrowable(
        uint256 trancheId,
        address yieldCurrency,
        address valueCurrency,
        address recipient
    )
        public
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
        return
            _collectYieldValueBorrowable(
                trancheId,
                yieldCurrency,
                valueCurrency,
                recipient
            );
    }

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
        address holdingStrategy = _holdingStrategies[trancheId];
        return
            IStrategy(holdingStrategy).viewYieldValueBorrowable(
                trancheId,
                yieldCurrency,
                valueCurrency
            );
    }

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

    function migrateStrategy(
        uint256 trancheId,
        address destination,
        address yieldToken,
        address yieldRecipient
    )
        external
        override
        returns (
            address token,
            uint256 tokenId,
            uint256 targetAmount
        )
    {
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to migrate tranche"
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
    }

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

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal override {
        super._safeTransfer(from, to, tokenId, _data);
        _containedIn[tokenId] = abi.decode(_data, (uint256));
    }

    function setupTrancheSlot() external {
        trancheIdService().setupTrancheSlot();
    }

    function _checkAssetToken(address token) internal view virtual {}

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
}
