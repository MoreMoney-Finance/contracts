// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./LyRedistributor.sol";

contract msAvaxRedistributor is LyRedistributor {
    constructor(address msAvax, address[] memory _rewardTokens, address _roles) LyRedistributor(msAvax, _rewardTokens, _roles) {
        _charactersPlayed.push(LIQUID_YIELD_REDISTRIBUTOR_MSAVAX);
    }
}