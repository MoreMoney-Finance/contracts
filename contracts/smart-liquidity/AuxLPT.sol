// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../MintableToken.sol";

contract AuxLPT is MintableToken {
    constructor(string memory _name, string memory _symbol, address _roles)
        MintableToken(_name, _symbol, 10_000_000 ether, _roles) {
            roleCache[msg.sender][SMART_LIQUIDITY] = Roles(_roles).roles(msg.sender, SMART_LIQUIDITY);
        }

    function isAuthorizedMinterBurner(address caller) internal override returns (bool) {
        if (roleCache[caller][SMART_LIQUIDITY]) {
            return true;
        } else {
            updateRoleCache(SMART_LIQUIDITY, caller);
            return roleCache[caller][SMART_LIQUIDITY];
        }
    }
}