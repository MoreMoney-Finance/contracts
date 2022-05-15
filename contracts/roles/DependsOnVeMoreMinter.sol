// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";

abstract contract DependsOnVeMoreMinter is DependentContract {
    constructor() {
        _dependsOnRoles.push(VEMORE_MINTER);
    }

    function isVeMoreMinter(address contr) internal view returns (bool) {
        return roleCache[contr][VEMORE_MINTER];
    }
}
