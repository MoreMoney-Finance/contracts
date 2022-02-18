// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../smart-liquidity/AuxLPT.sol";
import "../roles/DependsOnLiquidYield.sol";

contract msAvax is AuxLPT, DependsOnLiquidYield {
    constructor(address _roles)
        AuxLPT(LIQUID_YIELD, "MORE Staked AVAX", "msAVAX", _roles)
    {}
}
