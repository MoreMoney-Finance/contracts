// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IInterestRateController {

    function currentRatePer10k() external view returns (uint256);

    function updateRate() external;
}