// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./roles/RoleAware.sol";

abstract contract Executor is RoleAware {
    function execute() external virtual;
}
