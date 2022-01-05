// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./FlashAMMLiquidation.sol";

contract LPTFlashLiquidation is FlashAMMLiquidation {
    constructor(
        address _wrappedNative,
        address _defaultStable,
        address _curveZap,
        address _roles
    ) FlashAMMLiquidation(_wrappedNative, _defaultStable, _curveZap, _roles) {
        _charactersPlayed.push(LPT_LIQUIDATOR);
    }

    function unwrapAndUnwind(address token, address router)
        internal
        virtual
        override
    {
        address token0 = IUniswapV2Pair(token).token0();
        address token1 = IUniswapV2Pair(token).token1();

        IUniswapV2Router02(router).removeLiquidity(
            token0,
            token1,
            IERC20(token).balanceOf(address(this)),
            0,
            0,
            address(this),
            block.timestamp + 1
        );

        unwind(token0, router);
        unwind(token1, router);
    }
}
