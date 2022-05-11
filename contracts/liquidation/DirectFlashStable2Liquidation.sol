// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./FlashAMMStable2Liquidation.sol";

contract DirectFlashStable2Liquidation is FlashAMMStable2Liquidation {
    constructor(
        address _wrappedNative,
        address _defaultStable,
        address _curveZap,
        address[] memory stables,
        address _roles
    )
        FlashAMMStable2Liquidation(
            _wrappedNative,
            _defaultStable,
            _curveZap,
            stables,
            _roles
        )
    {
        _charactersPlayed.push(DIRECT_STABLE2_LIQUIDATOR);
    }

    function unwrapAndUnwind(address token, address router)
        internal
        virtual
        override
    {
        unwind(token, router);
    }
}
