// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";

abstract contract DependsOnLiquidator is DependentContract {
    constructor() {
        _dependsOnRoles.push(LIQUIDATOR);
    }

    function isLiquidator(address contr) internal view returns (bool) {
        return roleCache[contr][LIQUIDATOR];
    }
}
