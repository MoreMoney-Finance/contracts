// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./FlashAMMLiquidation.sol";

contract DirectFlashLiquidation is FlashAMMLiquidation {
    constructor(
        address _wrappedNative,
        address _defaultStable,
        address _curveZap,
        address _roles
    ) FlashAMMLiquidation(_wrappedNative, _defaultStable, _curveZap, _roles) {
        _charactersPlayed.push(DIRECT_LIQUIDATOR);
    }

    function unwrapAndUnwind(address token, address router)
        internal
        virtual
        override
    {
        unwind(token, router);
    }
}
