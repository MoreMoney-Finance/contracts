// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../oracles/TwapOracle.sol";

abstract contract DependsonTwapOracle is DependentContract {
    constructor() {
        _dependsOnCharacters.push(TRANCHE_ID_SERVICE);
    }

    function twapOracle() internal view returns (TwapOracle) {
        return TwapOracle(mainCharacterCache[TWAP_ORACLE]);
    }
}
