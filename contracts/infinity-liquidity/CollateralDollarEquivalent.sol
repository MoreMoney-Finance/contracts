// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../smart-liquidity/AuxLPT.sol";
import "../roles/DependsOnInfinityLiquidity.sol";

contract CollateralDollarEquivalent is AuxLPT, DependsOnInfinityLiquidity {
    constructor(address _roles)
        AuxLPT(INFINITY_LIQUIDITY, "MORE Collateral Dollar Equivalent", "MCDE", _roles)
    {}
}
