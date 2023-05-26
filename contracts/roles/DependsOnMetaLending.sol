// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../MetaLending.sol";

abstract contract DependsOnMetaLending is DependentContract {
    constructor() {
        _dependsOnCharacters.push(META_LENDING);
    }

    function metaLending() internal view returns (MetaLending) {
        return MetaLending(mainCharacterCache[META_LENDING]);
    }
}
