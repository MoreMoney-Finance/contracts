// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Executor.sol";
import "../roles/DependsOnIsolatedLending.sol";
import "../roles/DependsOnOracleRegistry.sol";
import "../Strategy.sol";

contract StrategyTokenActivation is
    Executor,
    DependsOnIsolatedLending,
    DependsOnOracleRegistry
{
    address[] public tokens;
    address[] public strategies;
    bytes[] public data;

    constructor(
        address[] memory _tokens,
        address[] memory _strategies,
        bytes[] memory _data,
        address _roles
    ) RoleAware(_roles) {
        tokens = _tokens;
        strategies = _strategies;
        data = _data;
    }

    function execute() external override {
        uint256 len = tokens.length;
        for (uint256 i; len > i; i++) {
            address token = tokens[i];

            Strategy strat = Strategy(strategies[i]);
            if (!strat.approvedToken(token)) {
                Strategy(strategies[i]).approveToken(token, data[i]);
            }
        }

        delete tokens;
        delete strategies;
        delete data;
        selfdestruct(payable(tx.origin));
    }
}
