// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./YieldYakAVAXStrategy2v2.sol";

contract AltYieldYakAVAXStrategy2v2 is YieldYakAVAXStrategy2v2 {
    constructor(address _wrappedNative, address _roles)
        YieldYakAVAXStrategy2v2(_wrappedNative, _roles)
    {}
}
