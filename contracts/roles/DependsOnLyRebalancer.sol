// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../liquid-yield/LyRebalancer.sol";

abstract contract DependsOnLyRebalancer is DependentContract {
    constructor() {
        _dependsOnCharacters.push(LIQUID_YIELD_REBALANCER);
    }

    function lyRebalancer() internal view returns (LyRebalancer) {
        return LyRebalancer(payable(mainCharacterCache[LIQUID_YIELD_REBALANCER]));
    }
}
