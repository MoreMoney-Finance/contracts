// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./YieldYakStrategy2v2.sol";

contract AltYieldYakStrategy2v2 is YieldYakStrategy2v2 {
    constructor(address _roles) YieldYakStrategy2v2(_roles) {}
}
