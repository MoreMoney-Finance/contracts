// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Executor.sol";
import "../roles/DependsOnIsolatedLending.sol";
import "../roles/DependsOnOracleRegistry.sol";
import "../Strategy.sol";

contract TokenActivation is
    Executor,
    DependsOnIsolatedLending,
    DependsOnOracleRegistry
{
    address[] public tokens;
    uint256[] public debtCeilings;
    uint256[] public feesPerMil;

    constructor(
        address[] memory _tokens,
        uint256[] memory _debtCeilings,
        uint256[] memory _feesPerMil,
        address _roles
    ) RoleAware(_roles) {
        tokens = _tokens;
        debtCeilings = _debtCeilings;
        feesPerMil = _feesPerMil;
    }

    function execute() external override {
        uint256 len = tokens.length;
        for (uint256 i; len > i; i++) {
            address token = tokens[i];
            isolatedLending().configureAsset(
                token,
                debtCeilings[i],
                feesPerMil[i]
            );
        }

        delete tokens;
        delete debtCeilings;
        delete feesPerMil;
        selfdestruct(payable(tx.origin));
    }
}
