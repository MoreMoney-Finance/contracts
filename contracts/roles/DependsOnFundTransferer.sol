// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";

abstract contract DependsOnFundTransferer is DependentContract {
    constructor() {
        _dependsOnRoles.push(FUND_TRANSFERER);
    }

    function isFundTransferer(address contr) internal view returns (bool) {
        return roleCache[contr][FUND_TRANSFERER];
    }
}
