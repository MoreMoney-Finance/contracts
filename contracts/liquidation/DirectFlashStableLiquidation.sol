// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./FlashAMMStableLiquidation.sol";

contract DirectFlashStableLiquidation is FlashAMMStableLiquidation {
    constructor(
        address _wrappedNative,
        address _defaultStable,
        address _curveZap,
        address[] memory stables,
        address _roles
    )
        FlashAMMStableLiquidation(
            _wrappedNative,
            _defaultStable,
            _curveZap,
            stables,
            _roles
        )
    {
        _charactersPlayed.push(DIRECT_STABLE_LIQUIDATOR);
    }

    function unwrapAndUnwind(address token, address router)
        internal
        virtual
        override
    {
        unwind(token, router);
    }
}
