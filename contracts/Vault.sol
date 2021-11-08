// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./ProxyOwnershipERC721.sol";
import "./Tranche.sol";
import "./TrancheIDAware.sol";
import "../interfaces/IVault.sol";
import "./roles/DependsOnTranche.sol";
import "./roles/DependsOnFundTransferer.sol";

abstract contract Vault is
    ProxyOwnershipERC721,
    IERC721Receiver,
    TrancheIDAware,
    IVault,
    DependsOnTranche,
    DependsOnFundTransferer
{
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    event VaultMinted(address indexed owner, uint256 indexed vaultId);
    uint256 nextVaultIndex = 1;

    mapping(uint256 => EnumerableSet.UintSet) internal vaultTranches;

    constructor(
        string memory _name,
        string memory _symbol,
        address _roles
    ) TrancheIDAware(_roles) ERC721(_name, _symbol) {}

    function _mintVault(address recipient) internal returns (uint256) {
        uint256 id = nextVaultIndex;
        nextVaultIndex++;

        _safeMint(recipient, id);
        return id;
    }

    function safeTransferTrancheFromVault(
        uint256 vaultId,
        uint256 trancheId,
        address recipient,
        uint256 recipientVaultId
    ) external {
        _checkAuthorizedAndTrancheInVault(msg.sender, vaultId, trancheId);
        Tranche(tranche(trancheId)).safeTransferFrom(
            address(this),
            recipient,
            trancheId,
            abi.encode(recipientVaultId)
        );
        EnumerableSet.UintSet storage vault = vaultTranches[vaultId];
        vault.remove(trancheId);

        require(isViable(vaultId), "Transfer makes vault unviable");
    }

    function mintTranche(
        address trancheContract,
        uint256 vaultId,
        address strategy,
        address assetToken,
        uint256 assetTokenId,
        uint256 assetAmount
    ) external override returns (uint256) {
        require(
            isAuthorized(_msgSender(), vaultId),
            "Not authorized to mint tranche from vault"
        );
        return
            Tranche(trancheContract).mintTranche(
                vaultId,
                strategy,
                assetToken,
                assetTokenId,
                assetAmount
            );
    }

    function registerMintTrancheForVault(
        address trancheContract,
        address minter,
        uint256 vaultId,
        address strategy,
        address assetToken,
        uint256 assetTokenId,
        uint256 assetAmount
    ) external {
        require(
            isFundTransferer(msg.sender),
            "Not authorized to transfer user funds"
        );
        require(
            isAuthorized(minter, vaultId),
            "Not authorized to withdraw from vault"
        );
        require(isTranche(trancheContract), "Not a valid tranche contract");
        Tranche(trancheContract).mintTranche(
            vaultId,
            strategy,
            assetToken,
            assetTokenId,
            assetAmount
        );
    }

    function deposit(
        uint256 vaultId,
        uint256 trancheId,
        uint256 tokenAmount
    ) external override {
        _checkAuthorizedAndTrancheInVault(_msgSender(), vaultId, trancheId);
        Tranche(tranche(trancheId)).registerDepositFor(
            msg.sender,
            trancheId,
            tokenAmount
        );
    }

    function withdraw(
        uint256 vaultId,
        uint256 trancheId,
        uint256 tokenAmount,
        address recipient
    ) external override {
        _checkAuthorizedAndTrancheInVault(_msgSender(), vaultId, trancheId);
        Tranche(tranche(trancheId)).withdraw(trancheId, tokenAmount, recipient);
        require(isViable(vaultId), "Vault no longer viable after withdraw");
    }

    function migrateStrategy(
        uint256 vaultId,
        uint256 trancheId,
        address targetStrategy,
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
        _checkAuthorizedAndTrancheInVault(_msgSender(), vaultId, trancheId);
        return
            Tranche(tranche(trancheId)).migrateStrategy(
                trancheId,
                targetStrategy,
                yieldToken,
                yieldRecipient
            );
    }

    function _checkAuthorizedAndTrancheInVault(
        address operator,
        uint256 vaultId,
        uint256 trancheId
    ) internal view {
        require(
            isAuthorized(operator, vaultId),
            "Not authorized to modify vault"
        );
        EnumerableSet.UintSet storage vault = vaultTranches[vaultId];
        require(vault.contains(trancheId), "Vault does not contain tranche");
    }

    function collectYield(
        uint256 vaultId,
        address currency,
        address recipient
    ) public override returns (uint256) {
        require(
            isAuthorized(msg.sender, vaultId),
            "Not authorized to modify vault"
        );
        uint256[] memory trancheIds = vaultTranches[vaultId].values();
        address[] memory trancheContracts = tranche(trancheIds);

        uint256 yield;
        for (uint256 i; trancheContracts.length > i; i++) {
            yield += Tranche(trancheContracts[i]).batchCollectYield(
                vaultTranches[vaultId].values(),
                currency,
                recipient
            );
        }

        return yield;
    }

    function viewYield(uint256 vaultId, address currency)
        public
        view
        override
        returns (uint256)
    {
        uint256[] memory trancheIds = vaultTranches[vaultId].values();
        address[] memory trancheContracts = tranche(trancheIds);

        uint256 yield;
        for (uint256 i; trancheContracts.length > i; i++) {
            yield += Tranche(trancheContracts[i]).batchViewYield(
                vaultTranches[vaultId].values(),
                currency
            );
        }
        return yield;
    }

    function viewBorrowable(uint256 vaultId, address currency)
        public
        view
        override
        returns (uint256)
    {
        uint256[] memory trancheIds = vaultTranches[vaultId].values();
        address[] memory trancheContracts = tranche(trancheIds);

        uint256 totalBorrowablePer10k;
        uint256 totalValue;
        for (uint256 i; trancheContracts.length > i; i++) {
            (uint256 value, uint256 borrowablePer10k) = Tranche(
                trancheContracts[i]
            ).batchViewValueBorrowable(
                    vaultTranches[vaultId].values(),
                    currency
                );
            totalValue += value;
            totalBorrowablePer10k += borrowablePer10k * value;
        }
        return totalBorrowablePer10k / totalValue;
    }

    function viewValue(uint256 vaultId, address currency)
        public
        view
        override
        returns (uint256)
    {
        uint256[] memory trancheIds = vaultTranches[vaultId].values();
        address[] memory trancheContracts = tranche(trancheIds);

        uint256 value;
        for (uint256 i; trancheContracts.length > i; i++) {
            value += Tranche(trancheContracts[i]).batchViewValue(
                vaultTranches[vaultId].values(),
                currency
            );
        }
        return value;
    }

    function collectYieldValueBorrowable(
        uint256 vaultId,
        address yieldCurrency,
        address valueCurrency,
        address recipient
    )
        public
        override
        returns (
            uint256 yield,
            uint256 value,
            uint256 borrowablePer10k
        )
    {
        uint256[] memory trancheIds = vaultTranches[vaultId].values();
        address[] memory trancheContracts = tranche(trancheIds);

        for (uint256 i; trancheContracts.length > i; i++) {
            (
                uint256 _yield,
                uint256 _value,
                uint256 _borrowablePer10k
            ) = Tranche(trancheContracts[i]).batchCollectYieldValueBorrowable(
                    vaultTranches[vaultId].values(),
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

    function onERC721Received(
        address from,
        address to,
        uint256 trancheId,
        bytes calldata data
    ) public virtual override returns (bytes4) {
        require(
            msg.sender == tranche(trancheId),
            "Only tranche contract NFTs accepted"
        );
        require(to == address(this), "not set to correct address");
        uint256 vaultId = abi.decode(data, (uint256));
        if (vaultId == 0) {
            vaultId = _mintVault(from);
        }
        _addTranche2Vault(vaultId, trancheId);
        return this.onERC721Received.selector;
    }

    function transferTranche(
        uint256 vaultId,
        address recipient,
        uint256 trancheId,
        uint256 recipientVaultId
    ) external {
        require(
            _isApprovedOrOwner(msg.sender, vaultId),
            "Not authorized to transfer out of vault"
        );

        IERC721(tranche(trancheId)).safeTransferFrom(
            address(this),
            recipient,
            trancheId,
            abi.encode(recipientVaultId)
        );
        _removeTrancheFromVault(vaultId, trancheId);
        require(isViable(vaultId), "Vault no longer viable");
    }

    function _addTranche2Vault(uint256 vaultId, uint256 trancheId)
        internal
        virtual
    {
        vaultTranches[vaultId].add(trancheId);
    }

    function _removeTrancheFromVault(uint256 vaultId, uint256 trancheId)
        internal
        virtual
    {
        vaultTranches[vaultId].remove(trancheId);
    }

    function getVaultTranches(uint256 vaultId)
        public
        view
        returns (uint256[] memory)
    {
        return vaultTranches[vaultId].values();
    }

    function isViable(uint256 vaultId)
        public
        view
        virtual
        override
        returns (bool);

    function tranche(uint256[] memory trancheIds)
        public
        view
        virtual
        returns (address[] memory)
    {
        address[] memory trancheContracts = new address[](trancheIds.length);
        for (uint256 i; trancheIds.length > i; i++) {
            trancheContracts[i] = tranche(trancheIds[i]);
        }

        return trancheContracts;
    }
}
