// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../OracleRegistry.sol";

abstract contract DependsOnOracleRegistry is DependentContract {
    constructor() {
        _dependsOnCharacters.push(ORACLE_REGISTRY);
    }

    function oracleRegistry() internal view returns (OracleRegistry) {
        return OracleRegistry(mainCharacterCache[ORACLE_REGISTRY]);
    }
}
