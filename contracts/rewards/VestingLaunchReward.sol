// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./VestingWrapper.sol";

contract VestingLaunchReward is VestingWrapper {
    constructor(address vestingToken)
        VestingWrapper("Moremoney Launch Reward", "MMLR", vestingToken)
    {}
}
