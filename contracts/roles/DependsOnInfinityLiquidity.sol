// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";

abstract contract DependsOnInfinityLiquidity is DependentContract {
    constructor() {
        _dependsOnRoles.push(INFINITY_LIQUIDITY);
    }

    function isInfinityLiquidity(address contr) internal view returns (bool) {
        return roleCache[contr][INFINITY_LIQUIDITY];
    }
}
