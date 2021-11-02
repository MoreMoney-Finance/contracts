// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";

abstract contract DependsOnFeeRecipient is DependentContract {
    constructor() {
        _dependsOnCharacters.push(FEE_RECIPIENT);
    }

    function feeRecipient() internal view returns (address) {
        return mainCharacterCache[FEE_RECIPIENT];
    }
}
