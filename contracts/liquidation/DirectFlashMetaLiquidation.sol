// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./FlashAMMMetaLiquidation.sol";

contract DirectFlashMetaLiquidation is FlashAMMMetaLiquidation {
    constructor(
        address _wrappedNative,
        address _defaultStable,
        address[] memory stables,
        address _roles
    ) FlashAMMMetaLiquidation(_wrappedNative, _defaultStable, stables, _roles) {
        _charactersPlayed.push(DIRECT_META_LIQUIDATOR);
    }

    function unwrapAndUnwind(address token, address router)
        internal
        virtual
        override
    {
        unwind(token, router);
    }
}
