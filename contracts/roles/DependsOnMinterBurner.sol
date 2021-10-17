// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";

abstract contract DependsOnMinterBurner is DependentContract {
    constructor() {
        _dependsOnRoles.push(MINTER_BURNER);
    }

    function isMinterBurner(address contr) internal view returns (bool) {
        return roleCache[contr][MINTER_BURNER];
    }
}
