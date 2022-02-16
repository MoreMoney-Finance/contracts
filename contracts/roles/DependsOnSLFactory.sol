// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../smart-liquidity/SLFactory.sol";

abstract contract DependsOnSLFactory is DependentContract {
    constructor() {
        _dependsOnCharacters.push(SMART_LIQUIDITY_FACTORY);
    }

    function slFactory()
        internal
        view
        returns (SLFactory)
    {
        return
            SLFactory(
                mainCharacterCache[SMART_LIQUIDITY_FACTORY]
            );
    }
}
