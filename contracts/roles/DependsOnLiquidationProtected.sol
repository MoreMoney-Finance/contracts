// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";

abstract contract DependsOnLiquidationProtected is DependentContract {
    constructor() {
        _dependsOnRoles.push(LIQUIDATION_PROTECTED);
    }

    function isLiquidationProtected(address contr)
        internal
        view
        returns (bool)
    {
        return roleCache[contr][LIQUIDATION_PROTECTED];
    }
}
