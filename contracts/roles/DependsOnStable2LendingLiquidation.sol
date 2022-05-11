// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../liquidation/StableLending2Liquidation.sol";

abstract contract DependsOnStable2LendingLiquidation is DependentContract {
    constructor() {
        _dependsOnCharacters.push(STABLE_LENDING2_LIQUIDATION);
    }

    function stableLendingLiquidation2()
        internal
        view
        returns (StableLending2Liquidation)
    {
        return
            StableLending2Liquidation(
                mainCharacterCache[STABLE_LENDING2_LIQUIDATION]
            );
    }
}
