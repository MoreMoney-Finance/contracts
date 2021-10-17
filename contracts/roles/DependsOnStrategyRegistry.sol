// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../StrategyRegistry.sol";

abstract contract DependsOnStrategyRegistry is DependentContract {
    constructor() {
        _dependsOnCharacters.push(STRATEGY_REGISTRY);
    }

    function strategyRegistry() internal view returns (StrategyRegistry) {
        return StrategyRegistry(mainCharacterCache[STRATEGY_REGISTRY]);
    }
}
