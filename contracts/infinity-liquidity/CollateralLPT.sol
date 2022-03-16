// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./CollateralDollarEquivalent.sol";

abstract contract CollateralLPT is AuxLPT {
    address public immutable wrappedAsset;
    constructor(address _wrappedAsset) {
        wrappedAsset = _wrappedAsset;
    }

    function harvest() external virtual;
}