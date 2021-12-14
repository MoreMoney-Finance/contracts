// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";

abstract contract DependsOnTrancheTransferer is DependentContract {
    constructor() {
        _dependsOnRoles.push(TRANCHE_TRANSFERER);
    }

    function isTrancheTransferer(address contr) internal view returns (bool) {
        return roleCache[contr][TRANCHE_TRANSFERER];
    }
}
