// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/IInterestRateController.sol";
import "./roles/RoleAware.sol";

contract InterestRateController is IInterestRateController, RoleAware {
    uint256 public override currentRatePer10k;
    uint256 public rateLastUpdated;

    constructor(address _roles) RoleAware(_roles) {
        _charactersPlayed.push(INTEREST_RATE_CONTROLLER);
    }

    function updateRate() external override {
        if (block.timestamp > rateLastUpdated + 20 hours) {
            // do stuff
        }
    }
}