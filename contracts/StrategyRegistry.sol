// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./RoleAware.sol";
import "../interfaces/IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// TODO: handle non-ERC20 migrations

contract StrategyRegistry is RoleAware {
    using SafeERC20 for IERC20;
    mapping(address => bool) public enabledStrategy;
    mapping(address => address) public replacementStrategy;

    constructor(address _roles) RoleAware(_roles) {}

    function enableStrategy(address strat) external onlyOwnerExec {
        enabledStrategy[strat] = true;
    }

    function disableStrategy(address strat) external onlyOwnerExec {
        enabledStrategy[strat] = false;
    }

    function replaceStrategy(address legacyStrat, address replacementStrat)
        external
        onlyOwnerExec
    {
        require(
            enabledStrategy[replacementStrat],
            "Replacement strategy is not enabled"
        );
        IStrategy(legacyStrat).migrateAllTo(replacementStrat);
        enabledStrategy[legacyStrat] = false;
        replacementStrategy[legacyStrat] = replacementStrat;
    }

    function getCurrentStrategy(address strat) external view returns (address) {
        address result = strat;
        while (replacementStrategy[result] != address(0)) {
            result = replacementStrategy[result];
        }
        return result;
    }

    function migrateTokenTo(address destination, address token) external {
        uint256 amount = IERC20(token).balanceOf(msg.sender);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(destination, amount);
    }
}
