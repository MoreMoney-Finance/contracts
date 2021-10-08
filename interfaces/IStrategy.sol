// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./IYieldBearing.sol";

interface IStrategy is IYieldBearing {
    function withdraw(uint256 trancheId, address recipient, uint256 amount) external;
    function isActive() external returns (bool);
    function migrateAllTo(address destination) external;
}