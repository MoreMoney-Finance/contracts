// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./ProxyOwnershipERC721.sol";
import "./RoleAware.sol";
import "./StrategyRegistry.sol";

contract Tranche is ProxyOwnershipERC721, RoleAware, IAsset {
    using Address for address;
    uint256 public nextTrancheId = 1;
    mapping(uint256 => address) public _holdingStrategies;
    mapping(address => address) public strategyReplacement;

    constructor(
        string memory _name,
        string memory _symbol,
        address _roles
    ) ERC721(_name, _symbol) RoleAware(_roles) {}

    function mintTranche(
        uint256 vaultId,
        address strategy,
        address assetToken,
        uint256 assetTokenId,
        uint256 assetAmount
    ) external returns (uint256 trancheId) {
        require(
            StrategyRegistry(strategyRegistry()).enabledStrategy(strategy),
            "Strategy not approved"
        );

        trancheId = nextTrancheId;
        nextTrancheId++;

        _holdingStrategies[trancheId] = strategy;
        _containedIn[trancheId] = vaultId;

        _safeMint(msg.sender, trancheId, abi.encode(vaultId));

        IStrategy(strategy).mintTranche(
            trancheId,
            assetToken,
            assetTokenId,
            assetAmount
        );
    }

    function deposit(uint256 trancheId, uint256 tokenAmount) external override {
        IStrategy(getCurrentHoldingStrategy(trancheId)).deposit(
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
        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
        IStrategy(holdingStrategy).withdraw(trancheId, tokenAmount, recipient);
    }

    function burnTranche(uint256 trancheId, address yieldToken, address recipient)
        external
        override
    {
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to withdraw"
        );

        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
        IStrategy(holdingStrategy).burnTranche(trancheId, yieldToken, recipient);
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
        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
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
        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
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

    function viewColRatioTargetPer10k(uint256 trancheId)
        public
        view
        override
        returns (uint256)
    {
        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
        return IStrategy(holdingStrategy).viewColRatioTargetPer10k(trancheId);
    }

    function batchViewColRatioTargetPer10k(uint256[] calldata trancheIds)
        public
        view
        returns (uint256)
    {
        uint256 crt;

        for (uint256 i; trancheIds.length > i; i++) {
            uint256 trancheId = trancheIds[i];

            crt += viewColRatioTargetPer10k(trancheId);
        }

        return crt;
    }

    function collectYieldValueColRatio(
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
        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
        return
            IStrategy(holdingStrategy).collectYieldValueColRatio(
                trancheId,
                yieldCurrency,
                valueCurrency,
                recipient
            );
    }

    function batchCollectYieldValueColRatio(
        uint256[] calldata trancheIds,
        address yieldCurrency,
        address valueCurrency,
        address recipient
    )
        public
        returns (
            uint256 yield,
            uint256 value,
            uint256 colRatio
        )
    {
        for (uint256 i; trancheIds.length > i; i++) {
            uint256 trancheId = trancheIds[i];
            (
                uint256 _yield,
                uint256 _value,
                uint256 _colRatio
            ) = collectYieldValueColRatio(
                    trancheId,
                    yieldCurrency,
                    valueCurrency,
                    recipient
                );
            yield += _yield;
            value += _value;
            colRatio += _colRatio;
        }
    }

    function isViable(uint256 trancheId) external view override returns (bool) {
        address tokenOwner = ownerOf(trancheId);
        if (tokenOwner.isContract()) {
            IProxyOwnership bearer = IProxyOwnership(tokenOwner);
            return bearer.isViable(_containedIn[trancheId]);
        } else {
            return true;
        }
    }

    function migrateStrategy(uint256 trancheId, address destination, address yieldToken, address yieldRecipient)
        external
        override
        returns (address token, uint256 tokenId, uint256 targetAmount)
    {
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to migrate tranche"
        );


        require(
            StrategyRegistry(strategyRegistry()).enabledStrategy(destination),
            "Strategy not approved"
        );

        _holdingStrategies[trancheId] = destination;

        address sourceStrategy = getCurrentHoldingStrategy(trancheId);
        (token, tokenId, targetAmount) = IStrategy(sourceStrategy).migrateStrategy(
            trancheId,
            destination,
            yieldToken,
            yieldRecipient
        );

        IStrategy(destination).acceptMigration(trancheId, sourceStrategy, token, tokenId, targetAmount);

    }

    function getCurrentHoldingStrategy(uint256 trancheId)
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
}
