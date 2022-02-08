// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../roles/RoleAware.sol";
import "./AuxLPT.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract SLFactory is RoleAware {
    constructor(address _roles) RoleAware(_roles) {}

    function initPool(string calldata poolName, string calldata poolSymbol) external returns (address, address) {
        require(isAuthorizedSL(msg.sender), "Not authorized to init a pool");
        return (
            address(new AuxLPT(
                string(abi.encodePacked("MONEY - ", poolName)), string(abi.encodePacked("MLPT-", poolSymbol)), address(roles))),
            address(new AuxLPT(string(abi.encodePacked("COUNTER - ", poolName)), string(abi.encodePacked("CLPT-", poolSymbol)),
                address(roles)))
            );
    }

    function isAuthorizedSL(address caller)
        internal
        returns (bool)
    {
        if (roleCache[caller][SMART_LIQUIDITY]) {
            return true;
        } else {
            updateRoleCache(SMART_LIQUIDITY, caller);
            return roleCache[caller][SMART_LIQUIDITY];
        }
    }
}