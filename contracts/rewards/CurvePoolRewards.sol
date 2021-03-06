// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./VestingStakingRewards.sol";
import "../roles/DependsOnCurvePool.sol";

contract CurvePoolRewards is VestingStakingRewards, DependsOnCurvePool {
    constructor(
        uint256 _vestingCliff,
        uint256 _vestingPeriod,
        address _roles
    )
        RoleAware(_roles)
        VestingStakingRewards(
            Roles(_roles).mainCharacters(PROTOCOL_TOKEN),
            Roles(_roles).mainCharacters(CURVE_POOL),
            _vestingCliff,
            _vestingPeriod
        )
    {}
}
