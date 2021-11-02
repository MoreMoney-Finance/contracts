// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../IsolatedLending.sol";

abstract contract DependsOnIsolatedLending is DependentContract {
    constructor() {
        _dependsOnCharacters.push(ISOLATED_LENDING);
    }

    function isolatedLending() internal view returns (IsolatedLending) {
        return IsolatedLending(mainCharacterCache[ISOLATED_LENDING]);
    }
}
