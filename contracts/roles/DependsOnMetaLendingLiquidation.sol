// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../liquidation/MetaLendingLiquidation.sol";

abstract contract DependsOnMetaLendingLiquidation is DependentContract {
    constructor() {
        _dependsOnCharacters.push(METALENDING_LIQUIDATION);
    }

    function stableLendingLiquidation2()
        internal
        view
        returns (MetaLendingLiquidation)
    {
        return
            MetaLendingLiquidation(mainCharacterCache[METALENDING_LIQUIDATION]);
    }
}
