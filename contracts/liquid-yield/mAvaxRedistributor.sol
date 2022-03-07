// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./LyRedistributor.sol";

contract mAvaxRedistributor is LyRedistributor {
    constructor(address mAvax, address[] memory _rewardTokens, address _roles) LyRedistributor(mAvax, _rewardTokens, _roles) {
        _charactersPlayed.push(LIQUID_YIELD_REDISTRIBUTOR_MAVAX);
    }
}