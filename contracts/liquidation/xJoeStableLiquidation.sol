// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import "./DirectFlashStableLiquidation.sol";
import "../../interfaces/IJoeBar.sol";

contract xJoeStableLiquidation is DirectFlashStableLiquidation {
    IJoeBar constant xJoe = IJoeBar(0x57319d41F71E81F3c65F2a47CA4e001EbAFd4F33);

    constructor(
        address _wrappedNative,
        address _defaultStable,
        address _curveZap,
        address[] memory stables,
        address _roles
    )
        DirectFlashStableLiquidation(
            _wrappedNative,
            _defaultStable,
            _curveZap,
            stables,
            _roles
        )
    {
        _charactersPlayed.push(LPT_LIQUIDATOR);
    }

    function unwrapAndUnwind(address token, address router)
        internal
        virtual
        override
    {
        require(token == address(xJoe), "Only for xJoe");
        xJoe.leave(xJoe.balanceOf(address(this)));
        super.unwrapAndUnwind(
            0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd,
            router
        );
    }
}
