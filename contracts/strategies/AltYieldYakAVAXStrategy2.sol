// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./YieldYakAVAXStrategy2.sol";

contract AltYieldYakAVAXStrategy2 is YieldYakAVAXStrategy2 {
    constructor(address _wrappedNative, address _roles)
        YieldYakAVAXStrategy2(_wrappedNative, _roles)
    {}
}
