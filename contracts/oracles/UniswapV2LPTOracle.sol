// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IOracle.sol";
import "../OracleAware.sol";

contract UniswapV2LPTOracle is IOracle, OracleAware {
    mapping(address => uint256) public colRatios;

    constructor(address _roles) TrancheIDAware(_roles) {}

    function fetchLPTState(address lpt)
        public
        view
        returns (
            address token0,
            address token1,
            uint256 reserve0,
            uint256 reserve1,
            uint256 totalSupply
        )
    {
        IUniswapV2Pair ammPair = IUniswapV2Pair(lpt);
        (reserve0, reserve1, ) = ammPair.getReserves();
        totalSupply = ammPair.totalSupply();

        token0 = ammPair.token0();
        token1 = ammPair.token1();
    }

    // TODO: can we safely ignore value drift here?
    function viewAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public view override returns (uint256) {
        (
            address token0,
            address token1,
            uint256 reserve0,
            uint256 reserve1,
            uint256 totalSupply
        ) = fetchLPTState(token);

        (uint256 resVal0, ) = _viewValueColRatio(token0, reserve0, pegCurrency);
        (uint256 resVal1, ) = _viewValueColRatio(token1, reserve1, pegCurrency);

        return (inAmount * (resVal0 + resVal1)) / totalSupply;
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
            uint256 reserve1,
            uint256 totalSupply
        ) = fetchLPTState(token);

        (uint256 resVal0, ) = _getValueColRatio(token0, reserve0, pegCurrency);
        (uint256 resVal1, ) = _getValueColRatio(token1, reserve1, pegCurrency);

        return (inAmount * (resVal0 + resVal1)) / totalSupply;
    }

    function viewPegAmountAndColRatio(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) external view override returns (uint256, uint256) {
        return (
            viewAmountInPeg(token, inAmount, pegCurrency),
            colRatios[token]
        );
    }

    function getPegAmountAndColRatio(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) external override returns (uint256, uint256) {
        return (getAmountInPeg(token, inAmount, pegCurrency), colRatios[token]);
    }

    function setColRatio(address lpt, uint256 colRatio) external onlyOwnerExec {
        colRatios[lpt] = colRatio;
    }
}
