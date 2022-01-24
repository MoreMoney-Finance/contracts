// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../liquidation/StableLendingLiquidation.sol";

abstract contract DependsOnStableLendingLiquidation is DependentContract {
    constructor() {
        _dependsOnCharacters.push(STABLE_LENDING_LIQUIDATION);
    }

    function stableLendingLiquidation()
        internal
        view
        returns (StableLendingLiquidation)
    {
        return
            StableLendingLiquidation(
                mainCharacterCache[STABLE_LENDING_LIQUIDATION]
            );
    }
}
