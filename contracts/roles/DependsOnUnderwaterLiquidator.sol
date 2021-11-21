// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";

abstract contract DependsOnUnderwaterLiquidator is DependentContract {
    constructor() {
        _dependsOnRoles.push(UNDERWATER_LIQUIDATOR);
    }

    function isUnderwaterLiquidator(address contr)
        internal
        view
        returns (bool)
    {
        return roleCache[contr][UNDERWATER_LIQUIDATOR];
    }
}
