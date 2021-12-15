// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";

abstract contract DependsOnCurvePool is DependentContract {
    constructor() {
        _dependsOnCharacters.push(CURVE_POOL);
    }

    function curvePool() internal view returns (address) {
        return mainCharacterCache[CURVE_POOL];
    }
}
