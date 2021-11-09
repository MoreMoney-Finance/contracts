// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./roles/RoleAware.sol";
import "../interfaces/IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// TODO: handle non-ERC20 migrations

/// Central clearing house for all things strategy, for activating and migrating
contract StrategyRegistry is RoleAware {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    mapping(address => address) public replacementStrategy;

    EnumerableSet.AddressSet enabledStrategies;
    EnumerableSet.AddressSet allStrategiesEver;

    mapping(address => uint256) public _tokenCount;
    uint256 public totalTokenStratRows;
    uint256 public enabledTokenStratRows;

    constructor(address _roles) RoleAware(_roles) {
        _charactersPlayed.push(STRATEGY_REGISTRY);
    }

    /// View all enabled strategies
    function allEnabledStrategies() external view returns (address[] memory) {
        return enabledStrategies.values();
    }

    /// Enable a strategy
    function enableStrategy(address strat) external onlyOwnerExec {
        enabledStrategies.add(strat);
        allStrategiesEver.add(strat);
        updateTokenCount(strat);
    }

    /// Disable a strategy
    function disableStrategy(address strat) external onlyOwnerExec {
        totalTokenStratRows -= _tokenCount[strat];
        enabledStrategies.remove(strat);
    }

    /// View whether a strategy is enabled
    function enabledStrategy(address strat) external view returns (bool) {
        return enabledStrategies.contains(strat);
    }

    /// Replace a strategy and migrate all its assets to replacement
    /// beware not to introduce cycles :)
    function replaceStrategy(address legacyStrat, address replacementStrat)
        external
        onlyOwnerExec
    {
        require(
            enabledStrategies.contains(replacementStrat),
            "Replacement strategy is not enabled"
        );
        IStrategy(legacyStrat).migrateAllTo(replacementStrat);
        enabledStrategies.remove(legacyStrat);
        replacementStrategy[legacyStrat] = replacementStrat;
    }

    /// Get strategy or any replacement of it
    function getCurrentStrategy(address strat) external view returns (address) {
        address result = strat;
        while (replacementStrategy[result] != address(0)) {
            result = replacementStrategy[result];
        }
        return result;
    }

    /// Endpoint for strategies to deposit tokens for migration destinations
    /// to later withdraw
    function depositMigrationTokens(address destination, address token)
        external
    {
        uint256 amount = IERC20(token).balanceOf(msg.sender);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(destination, amount);
    }

    /// update accounting cache for view function
    function updateTokenCount(address strat) public {
        require(enabledStrategies.contains(strat), "Not an enabled strategy!");
        uint256 oldCount = _tokenCount[strat];
        uint256 newCount = IStrategy(strat).approvedTokensCount();
        totalTokenStratRows = totalTokenStratRows + newCount - oldCount;
        _tokenCount[strat] = newCount;
    }

    /// Return a big ol list of strategy metadata
    function viewAllEnabledStrategyMetadata()
        external
        view
        returns (IStrategy.StrategyMetadata[] memory)
    {
        IStrategy.StrategyMetadata[]
            memory result = new IStrategy.StrategyMetadata[](
                totalTokenStratRows
            );
        uint256 enabledTotal = enabledStrategies.length();
        uint256 resultI;
        for (uint256 stratI; enabledTotal > stratI; stratI++) {
            IStrategy strat = IStrategy(enabledStrategies.at(stratI));
            IStrategy.StrategyMetadata[] memory meta = strat
                .viewAllStrategyMetadata();
            for (uint256 i; meta.length > i; i++) {
                result[resultI + i] = meta[i];
            }
            resultI += meta.length;
        }

        return result;
    }
}
