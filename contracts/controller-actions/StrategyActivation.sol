// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Executor.sol";
import "../roles/DependsOnIsolatedLending.sol";
import "../roles/DependsOnOracleRegistry.sol";
import "../Strategy.sol";

contract StrategyActivation is
    Executor,
    DependsOnIsolatedLending,
    DependsOnOracleRegistry
{
    address[] public tokens;
    address[] public strategies;

    constructor(
        address[] memory _tokens,
        address[] memory _strategies,
        address _roles
    ) RoleAware(_roles) {
        tokens = _tokens;
        strategies = _strategies;
    }

    function execute() external override {
        address stable = roles.mainCharacters(STABLECOIN);
        uint256 len = tokens.length;
        for (uint256 i; len > i; i++) {
            address token = tokens[i];

            Strategy strat = Strategy(strategies[i]);
            if (!strat.approvedToken(token)) {
                Strategy(strategies[i]).approveToken(token);
            }
        }

        delete tokens;
        delete strategies;
        selfdestruct(payable(tx.origin));
    }
}
