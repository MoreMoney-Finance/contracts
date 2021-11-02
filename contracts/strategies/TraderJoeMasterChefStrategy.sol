// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./MasterChefStrategy.sol";

contract TraderJoeMasterChefStrategy is MasterChefStrategy {
    constructor(address _roles)
        MasterChefStrategy(
            "Trader Joe self-repaying",
            0xd6a4F121CA35509aF06A0Be99093d08462f53052,
            0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd,
            _roles
        )
    {}
}
