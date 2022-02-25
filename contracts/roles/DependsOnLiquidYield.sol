// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";

abstract contract DependsOnLiquidYield is DependentContract {
    constructor() {
        _dependsOnRoles.push(LIQUID_YIELD);
    }

    function isLiquidYield(address contr) internal view returns (bool) {
        return roleCache[contr][LIQUID_YIELD];
    }
}
