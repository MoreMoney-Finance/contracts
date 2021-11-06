// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./StakingRewardsStrategy.sol";

contract PangolinStakingRewardsStrategy is StakingRewardsStrategy {
    constructor(address _roles)
        StakingRewardsStrategy(
            "Pangolin self-repaying",
            0x60781C2586D68229fde47564546784ab3fACA982,
            _roles
        )
    {}
}
