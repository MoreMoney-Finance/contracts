// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../StableLending.sol";

abstract contract DependsOnStableLending is DependentContract {
    constructor() {
        _dependsOnCharacters.push(STABLE_LENDING);
    }

    function stableLending() internal view returns (StableLending) {
        return StableLending(mainCharacterCache[STABLE_LENDING]);
    }
}
