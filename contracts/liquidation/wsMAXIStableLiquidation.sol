// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import "./DirectFlashStableLiquidation.sol";
import "../../interfaces/IwsMAXI.sol";
import "../../interfaces/IMaxiStaking.sol";

contract wsMAXIStableLiquidation is DirectFlashStableLiquidation {
    using SafeERC20 for IERC20;

    IwsMAXI constant wsMAXI =
        IwsMAXI(0x2148D1B21Faa7eb251789a51B404fc063cA6AAd6);
    IERC20 constant sMAXI = IERC20(0xEcE4D1b3C2020A312Ec41A7271608326894076b4);
    IMaxiStaking constant staking =
        IMaxiStaking(0x6d7AD602Ec2EFdF4B7d34A9A53f92F06d27b82B1);
    address constant maxi = 0x7C08413cbf02202a1c13643dB173f2694e0F73f0;

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
        require(token == address(wsMAXI), "Only for wsMAXI");
        wsMAXI.unwrap(wsMAXI.balanceOf(address(this)));

        uint256 sMaxiBalance = sMAXI.balanceOf(address(this));
        sMAXI.safeIncreaseAllowance(address(staking), sMaxiBalance);
        staking.unstake(sMaxiBalance, false);

        super.unwrapAndUnwind(maxi, router);
    }
}
