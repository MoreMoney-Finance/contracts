// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../liquidation/IsolatedLendingLiquidation.sol";

abstract contract DependsOnIsolatedLendingLiquidation is DependentContract {
    constructor() {
        _dependsOnCharacters.push(ISOLATED_LENDING_LIQUIDATION);
    }

    function isolatedLendingLiquidation()
        internal
        view
        returns (IsolatedLendingLiquidation)
    {
        return
            IsolatedLendingLiquidation(
                mainCharacterCache[ISOLATED_LENDING_LIQUIDATION]
            );
    }
}
