// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/IInterestRateController.sol";
import "./roles/RoleAware.sol";

contract InterestRateController is IInterestRateController, RoleAware {
    uint256 public rateLastUpdated;
    uint256 public baseRatePer10k = 300;

    constructor(address _roles) RoleAware(_roles) {
        _charactersPlayed.push(INTEREST_RATE_CONTROLLER);
    }

    function updateRate() external override {
        if (block.timestamp > rateLastUpdated + 20 hours) {
            // do stuff
        }
    }

    function setBaseRate(uint256 newRate) external onlyOwnerExec {
        require(1000 >= newRate, "Excessive rates not allowed");
        baseRatePer10k = newRate;
    }

    function currentRatePer10k() external override view returns (uint256) {
        return baseRatePer10k;
    }
}