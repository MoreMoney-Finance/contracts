// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "../../interfaces/IInterestRateController.sol";

abstract contract DependsOnInterestRateController is DependentContract {
    constructor() {
        _dependsOnCharacters.push(INTEREST_RATE_CONTROLLER);
    }

    function interestRateController() internal view returns (IInterestRateController) {
        return IInterestRateController(mainCharacterCache[INTEREST_RATE_CONTROLLER]);
    }
}
