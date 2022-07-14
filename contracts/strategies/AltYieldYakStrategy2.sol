// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./YieldYakStrategy2.sol";

contract AltYieldYakStrategy2 is YieldYakStrategy2 {
    constructor(address _roles) YieldYakStrategy2(_roles) {}
}
