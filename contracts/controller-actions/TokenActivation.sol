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
    address[] public oracles;
    uint256[] public debtCeilings;
    uint256[] public feesPerMil;
    uint256[] public colRatios;
    bytes[] public data;

    constructor(
        address[] memory _tokens,
        uint256[] memory _debtCeilings,
        uint256[] memory _feesPerMil,
        uint256[] memory _colRatios,
        address[] memory _oracles,
        bytes[] memory _data,
        address _roles
    ) RoleAware(_roles) {
        tokens = _tokens;
        debtCeilings = _debtCeilings;
        feesPerMil = _feesPerMil;
        colRatios = _colRatios;
        oracles = _oracles;
        data = _data;
    }

    function execute() external override {
        address stable = roles.mainCharacters(STABLECOIN);
        uint256 len = tokens.length;
        for (uint256 i; len > i; i++) {
            address token = tokens[i];
            isolatedLending().configureAsset(
                token,
                debtCeilings[i],
                feesPerMil[i]
            );

            oracleRegistry().setOracleParams(
                token,
                stable,
                oracles[i],
                colRatios[i],
                data[i]
            );
        }

        delete tokens;
        delete oracles;
        delete debtCeilings;
        delete feesPerMil;
        delete colRatios;
        selfdestruct(payable(tx.origin));
    }
}
