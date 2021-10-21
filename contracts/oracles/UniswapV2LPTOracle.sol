// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IOracle.sol";
import "./Oracle.sol";
import "./OracleAware.sol";
import "./TwapOracle.sol";
import "../roles/DependsOnTwapOracle.sol";

contract UniswapV2LPTOracle is Oracle, OracleAware, DependsonTwapOracle {
    constructor(address _roles) RoleAware(_roles) {}

    function viewAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public view override returns (uint256) {
        (
            address token0,
            address token1,
            uint256 reserve0,
            uint256 reserve1
        ) = twapOracle().viewTwapReserves(token);

        (uint256 resVal0, ) = _viewValueColRatio(token0, reserve0, pegCurrency);
        (uint256 resVal1, ) = _viewValueColRatio(token1, reserve1, pegCurrency);

        return
            (inAmount * (resVal0 + resVal1)) /
            IUniswapV2Pair(token).totalSupply();
    }

    function getAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public override returns (uint256) {
        (
            address token0,
            address token1,
            uint256 reserve0,
            uint256 reserve1
        ) = twapOracle().getTwapReserves(token);

        (uint256 resVal0, ) = _getValueColRatio(token0, reserve0, pegCurrency);
        (uint256 resVal1, ) = _getValueColRatio(token1, reserve1, pegCurrency);

        return
            (inAmount * (resVal0 + resVal1)) /
            IUniswapV2Pair(token).totalSupply();
    }
}
