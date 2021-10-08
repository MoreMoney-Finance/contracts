// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./ProxyOwnershipERC721.sol";
import "./Tranche.sol";

abstract contract Vault is ProxyOwnershipERC721, IERC721Receiver {
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    event VaultMinted(address indexed owner, uint256 indexed vaultId);

    address public immutable trancheContract;
    uint256 nextVaultIndex = 1;

    mapping(uint256 => EnumerableSet.UintSet) internal vaultTranches;

    constructor (address _trancheContract, string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        trancheContract = _trancheContract;
    }

    function _mintVault(address recipient) internal returns (uint256) {
        uint256 id = nextVaultIndex;
        nextVaultIndex++;

        _safeMint(recipient, id);
        return id;
    }

    function safeTransferTrancheFromVault(uint256 vaultId, uint256 trancheId, address recipient) external {
        require(_isApprovedOrOwner(_msgSender(), vaultId), "Not authorized to withdraw from vault");
        EnumerableSet.UintSet storage vault = vaultTranches[vaultId];
        require(vault.contains(trancheId), "Vault does not contain tranche");
        IERC721(trancheContract).safeTransferFrom(address(this), recipient, trancheId);
        vault.remove(trancheId);
    }

    function onERC721Received(
        address from,
        address to,
        uint256 trancheId,
        bytes calldata data
    ) public virtual override returns (bytes4) {
        require(msg.sender == trancheContract, "Only tranche contract NFTs accepted");
        require(to == address(this), "not set to correct address");
        uint256 vaultId = abi.decode(data, (uint256));
        if (vaultId == 0) {
            vaultId = _mintVault(from);
        }
        _addTranche2Vault(vaultId, trancheId);
        return this.onERC721Received.selector;
    }

    function transferTranche(uint256 trancheId, address recipient) external {
        uint256 vaultId = containedIn[trancheContract][trancheId];
        require(_isApprovedOrOwner(msg.sender, vaultId), "Not authorized to transfer out of vault");
        
        IERC721(trancheContract).safeTransferFrom(address(this), recipient, trancheId);
        require(viableVault(vaultId), "Vault no longer viable");
    }

    function _addTranche2Vault(uint256 vaultId, uint256 trancheId) internal {
        vaultTranches[vaultId].add(trancheId);
        containedIn[trancheContract][trancheId] = vaultId;
    }

    function getVaultTranches(uint256 vaultId) public view returns (uint256[] memory) {
        return vaultTranches[vaultId].values();
    }

    function getYield(address currency, uint256 vaultId, address recipient) public virtual override {
        _checkApprovedOwnerOrProxy(msg.sender, vaultId);
        EnumerableSet.UintSet storage tranches = vaultTranches[vaultId]; 
        for (uint256 i; tranches.length() > i; i++) {
            IYieldBearing(trancheContract).getYield(currency, tranches.at(i), recipient);
        }
    }
    
    function viewYield(address currency, uint256 vaultId) public virtual override view returns (uint256 yield) {
        EnumerableSet.UintSet storage tranches = vaultTranches[vaultId]; 
        for (uint256 i; tranches.length() > i; i++) {
            yield += IYieldBearing(trancheContract).viewYield(currency, tranches.at(i));
        }
    }

    function viableVault(uint256 vaultId) public virtual returns (bool);
}

// allow as many wrappers as we may want, but have a unique ID space for our wrappers?
// or we tie it to a fixed issuer of NFTs also has its benefits