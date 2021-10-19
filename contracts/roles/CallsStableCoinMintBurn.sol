// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependsOnStableCoin.sol";

abstract contract CallsStableCoinMintBurn is DependsOnStableCoin {
    constructor() {
        _rolesPlayed.push(MINTER_BURNER);
    }

    function _mintStable(address account, uint256 amount) internal {
        stableCoin().mint(account, amount);
    }

    function _burnStable(address account, uint256 amount) internal {
        stableCoin().burn(account, amount);
    }
}
