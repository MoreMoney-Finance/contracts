// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./MasterChefStrategy.sol";

/// Uses TJ masterchef
contract TraderJoeMasterChefStrategy is MasterChefStrategy {
    constructor(address _roles)
        MasterChefStrategy(
            "Trader Joe self-repaying",
            0x188bED1968b795d5c9022F6a0bb5931Ac4c18F00,
            0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd,
            _roles
        )
    {}
}
