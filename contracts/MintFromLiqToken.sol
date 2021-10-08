// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./MintFromCollateral.sol";
import "./Fund.sol";

/// Lending contract with LPT as collateral class
abstract contract MintFromLiqToken is MintFromCollateral {
    using SafeERC20 for IUniswapV2Pair;

    IUniswapV2Pair public immutable ammPair;
    address oracleForToken0;
    address oracleForToken1;

    uint256 constant STABLE_DECIMALS = 1e18;
    uint256 public oracleFreshnessPermil = 30;

    constructor(
        address _ammPair,
        address _oracleForToken0,
        address _oracleForToken1,
        uint256 _reservePermil,
        address _roles
    ) MintFromCollateral(_roles) {
        ammPair = IUniswapV2Pair(_ammPair);
        reservePermil = _reservePermil;
        oracleForToken0 = _oracleForToken0;
        oracleForToken1 = _oracleForToken1;
    }

    /// Withdraw collateral from source account
    function collectCollateral(address source, uint256 collateralAmount)
        internal
        virtual
        override
    {
        Fund(fund()).depositFor(source, address(ammPair), collateralAmount);
    }

    /// Return collateral to user
    function returnCollateral(address recipient, uint256 collateralAmount)
        internal
        virtual
        override
    {
        Fund(fund()).withdraw(address(ammPair), recipient, collateralAmount);
    }

    /// Returns the stored collateral amount
    function viewTargetCollateralAmount(CollateralAccount memory account)
        public
        view
        virtual
        returns (uint256 collateralVal)
    {
        return account.collateral;
    }

    /// Get USD value of a specific collateral amount
    function getCollateralValue(CollateralAccount memory account)
        public
        view
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

        uint256 reserve0DollarValue = (STABLE_DECIMALS *
            reserve0 *
            uint256(token0Price)) / 10**oracle0Decimals;
        uint256 reserve1DollarValue = (STABLE_DECIMALS *
            reserve1 *
            uint256(token1Price)) / 10**oracle1Decimals;

        require(
            (reserve0DollarValue * (1000 + oracleFreshnessPermil)) / 1000 >
                reserve1DollarValue &&
                (reserve1DollarValue * (1000 + oracleFreshnessPermil)) / 1000 >
                reserve0DollarValue,
            "Oracle out of sync with LP price"
        );

        // liquidity token value
        uint256 reserveDollarValue = reserve0DollarValue + reserve1DollarValue;

        collateralVal =
            (reserveDollarValue *
                viewTargetCollateralAmount(account)) /
            liqTokenTotal;
    }

    /// Retrieve current prices from chainlink oracle
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

    /// Set permil threshold for max price drift between chainlink and the liquidity pool pair
    function setOracleFreshnessPermil(uint256 freshnessParam)
        external
        onlyOwnerExec
    {
        oracleFreshnessPermil = freshnessParam;
    }
}
