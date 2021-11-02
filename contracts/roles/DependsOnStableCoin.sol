// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../Stablecoin.sol";

abstract contract DependsOnStableCoin is DependentContract {
    constructor() {
        _dependsOnCharacters.push(STABLECOIN);
    }

    function stableCoin() internal view returns (Stablecoin) {
        return Stablecoin(mainCharacterCache[STABLECOIN]);
    }
}
