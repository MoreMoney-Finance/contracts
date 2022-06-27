// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../StableLending2.sol";

abstract contract DependsOnStableLending2 is DependentContract {
    constructor() {
        _dependsOnCharacters.push(STABLE_LENDING_2);
    }

    function stableLending2() internal view returns (StableLending2) {
        return StableLending2(mainCharacterCache[STABLE_LENDING_2]);
    }
}
