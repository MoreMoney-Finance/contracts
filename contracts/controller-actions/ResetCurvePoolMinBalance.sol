// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Executor.sol";
import "../roles/DependsOnStableCoin.sol";
import "../roles/DependsOnCurvePool.sol";

contract ResetCurvePoolMinBalance is Executor, DependsOnCurvePool, DependsOnStableCoin {
    constructor(address _roles) RoleAware(_roles) {
        _rolesPlayed.push(MINTER_BURNER);
    }

    function execute() external override {
        Stablecoin stable = stableCoin();
        address pool = curvePool();

        stable.setMinBalance(pool, 0);
    }
}