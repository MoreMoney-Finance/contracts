// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";

import "./MintFromCollateral.sol";
import "./Fund.sol";

abstract contract MintFromLiqToken is MintFromCollateral {
    IUniswapV2Pair public immutable ammPair;
    address oracleForToken0;
    address oracleForToken1;

    uint256 constant STABLE_DECIMALS = 18;

    constructor(
        address _ammPair,
        address _oracleForToken0,
        address _oracleForToken1,
        uint256 _reservePercent,
        address _roles
    ) MintFromCollateral(_roles) {
        ammPair = IUniswapV2Pair(_ammPair);
        reservePercent = _reservePercent;
        oracleForToken0 = _oracleForToken0;
        oracleForToken1 = _oracleForToken1;
    }

    function collectCollateral(address source, uint256 collateralAmount)
        internal
        override
    {
        Fund(fund()).depositFor(source, address(ammPair), collateralAmount);
    }

    function returnCollateral(address recipient, uint256 collateralAmount)
        internal
        override
    {
        Fund(fund()).withdraw(address(ammPair), recipient, collateralAmount);
    }

    function getCollateralValue(uint256 collateralAmount)
        public
        override
        returns (uint256 collateralVal)
    {
        // get liquidity token per token0 and token1
        (uint112 reserve0, uint112 reserve1, ) = ammPair.getReserves();
        uint256 liqTokenTotal = ammPair.totalSupply();

        // get current price from oracle
        (
            int256 token0Price,
            int256 token1Price,
            uint256 oracle0Decimals,
            uint256 oracle1Decimals
        ) = getCurrentPricesFromOracle();

        // liquidity token value
        uint256 reserveDollarValue =
            (STABLE_DECIMALS * reserve0 * uint256(token0Price)) /
                oracle0Decimals +
                (STABLE_DECIMALS * reserve1 * uint256(token1Price)) /
                oracle1Decimals;

        collateralVal =
            (reserveDollarValue * collateralAmount) / liqTokenTotal;
    }

    function getCurrentPricesFromOracle()
        public
        view
        returns (
            int256,
            int256,
            uint256,
            uint256
        )
    {
        AggregatorV3Interface oracle0 = AggregatorV3Interface(oracleForToken0);
        AggregatorV3Interface oracle1 = AggregatorV3Interface(oracleForToken1);
        (
            uint80 roundID,
            int256 token0Price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = oracle0.latestRoundData();

        int256 token1Price;
        (roundID, token1Price, startedAt, timeStamp, answeredInRound) = oracle1
            .latestRoundData();

        return (
            token0Price,
            token1Price,
            oracle0.decimals(),
            oracle1.decimals()
        );
    }
}
