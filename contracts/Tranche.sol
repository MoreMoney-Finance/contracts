// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./ProxyOwnershipERC721.sol";
import "./RoleAware.sol";
import "./StrategyRegistry.sol";

contract Tranche is ProxyOwnershipERC721, RoleAware {
    using Address for address;
    uint256 public nextTrancheId = 1;
    mapping(uint256 => address) public _holdingStrategies;
    mapping(address => address) public strategyReplacement;
    
    constructor (string memory _name, string memory _symbol, address _roles) ERC721(_name, _symbol) RoleAware(_roles) {}

    function _mintTranche(address vaultContract, uint256 vaultId, address strategy) internal returns (uint256 trancheId) {
        require(StrategyRegistry(strategyRegistry()).enabledStrategy(strategy), "Strategy not approved to mint tranches");

        trancheId = nextTrancheId;
        nextTrancheId++;

        _holdingStrategies[trancheId] = strategy;
        _safeMint(vaultContract, trancheId, abi.encode(vaultId));
    }

    function mintTranche(address vaultContract, uint256 vaultId) external returns (uint256) {
        return _mintTranche(vaultContract, vaultId, msg.sender);
    }

    function mintTrancheContaining(address vaultContract, uint256 vaultId, address wrappedTokenContract, uint256 wrappedId) external returns (uint256 trancheId) {
        trancheId = _mintTranche(vaultContract, vaultId, msg.sender);
        containedIn[wrappedTokenContract][wrappedId] = trancheId;
    }


    function getYield(address currency, uint256 trancheId, address recipient) public virtual override {
        _checkApprovedOwnerOrProxy(msg.sender, trancheId);

        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
        if (holdingStrategy != address(0)) {
            IYieldBearing(holdingStrategy).getYield(currency, trancheId, recipient);
        }
    }
    
    function viewYield(address currency, uint256 trancheId) public virtual override view returns (uint256) {
        address holdingStrategy = getCurrentHoldingStrategy(trancheId);
        if (holdingStrategy != address(0)) {
            return IYieldBearing(holdingStrategy).viewYield(currency, trancheId);
        } else {
            return 0;
        }
    }

    function checkViability(uint256 trancheId) external override view returns (bool) {
        address tokenOwner = ownerOf(trancheId);
        if (tokenOwner.isContract()) {
            IProxyOwnership tokenProxy = IProxyOwnership(tokenOwner);
            return tokenProxy.checkViability(tokenProxy.containedIn(address(this), trancheId));
        } else {
            return true;
        }
    }

    function migrateTrancheTo(uint256 trancheId, address destination) external override {
        _checkApprovedOwnerOrProxy(msg.sender, trancheId);
        IStrategy(getCurrentHoldingStrategy(trancheId)).migrateTrancheTo(trancheId, destination);
        _holdingStrategies[trancheId] = destination;
    }

    function getCurrentHoldingStrategy(uint256 trancheId) public view returns (address) {
        return StrategyRegistry(strategyRegistry()).getCurrentStrategy(_holdingStrategies[trancheId]);
    }
}