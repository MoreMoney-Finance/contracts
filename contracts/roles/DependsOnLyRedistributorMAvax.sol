// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../liquid-yield/LyRedistributor.sol";

abstract contract DependsOnLyRedistributorMAvax is DependentContract {
    constructor() {
        _dependsOnCharacters.push(LIQUID_YIELD_REDISTRIBUTOR_MAVAX);
    }

    function lyRedistributorMAvax() internal view returns (LyRedistributor) {
        return LyRedistributor(mainCharacterCache[LIQUID_YIELD_REDISTRIBUTOR_MAVAX]);
    }
}
