// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Executor.sol";
import "../roles/DependsOnStrategyRegistry.sol";
import "../DependencyController.sol";

contract ContractManagement is Executor, DependsOnStrategyRegistry {
    address[] toManage;
    address[] toDisable;
    address[] strategies;

    constructor(
        address[] memory _toManage,
        address[] memory _toDisable,
        address[] memory _strategies,
        address _roles
    ) RoleAware(_roles) {
        toManage = _toManage;
        toDisable = _toDisable;
        strategies = _strategies;
    }

    function execute() external override {
        DependencyController dc = DependencyController(msg.sender);

        for (uint256 i; toDisable.length > i; i++) {
            dc.disableContract(toDisable[i]);
        }

        for (uint256 i; toManage.length > i; i++) {
            dc.manageContract(toManage[i]);
        }

        StrategyRegistry registry = strategyRegistry();
        for (uint256 i; strategies.length > i; i++) {
            registry.enabledStrategy(strategies[i]);
        }

        delete toManage;
        delete toDisable;
        delete strategies;
        selfdestruct(payable(tx.origin));
    }
}
