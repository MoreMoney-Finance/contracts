// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./FlashAMMStableLiquidation.sol";

contract LPTFlashStableLiquidation is FlashAMMStableLiquidation {
    using SafeERC20 for IERC20;

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
        _charactersPlayed.push(LPT_STABLE_LIQUIDATOR);
    }

    function unwrapAndUnwind(address token, address router)
        internal
        virtual
        override
    {
        address token0 = IUniswapV2Pair(token).token0();
        address token1 = IUniswapV2Pair(token).token1();

        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeIncreaseAllowance(router, balance);
        IUniswapV2Router02(router).removeLiquidity(
            token0,
            token1,
            balance,
            0,
            0,
            address(this),
            block.timestamp + 1
        );

        unwind(token0, router);
        unwind(token1, router);
    }
}
