// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Oracle.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

/// Use UniswapV2-compatible pairs to kepp up a twap oracle
/// In all this one must be careful of staleness
contract TwapOracle is Oracle {
    uint256 constant FP112 = 2**112;
    uint256 constant FP56 = 2**56;

    struct TwapOracleState {
        address token0;
        address token1;
        uint256 cumulativePrice0;
        uint256 price0FP;
        uint256 lastUpdated;
        uint256 kLast;
        uint256 totalSupplyLast;
        uint256 kCurrent;
        uint256 totalSupplyCurrent;
    }

    mapping(address => TwapOracleState) public pairState;

    mapping(address => mapping(address => address)) public bestPairByTokens;

    uint256 priceUpdateWindow = 5 minutes;

    constructor(address _roles) RoleAware(_roles) {
        _charactersPlayed.push(TWAP_ORACLE);
    }

    /// View TwapOracleState of pair
    function viewPairState(address pair)
        public
        view
        returns (TwapOracleState memory oracleState)
    {
        oracleState = pairState[pair];

        (, , uint256 pairLastUpdated) = IUniswapV2Pair(pair).getReserves();
        uint256 timeDelta = pairLastUpdated - oracleState.lastUpdated;

        if (timeDelta > priceUpdateWindow) {
            uint256 newCumul0 = IUniswapV2Pair(pair).price0CumulativeLast();
            oracleState.price0FP =
                (newCumul0 - oracleState.cumulativePrice0) /
                timeDelta;
            oracleState.cumulativePrice0 = newCumul0;
            oracleState.lastUpdated = pairLastUpdated;

            oracleState.kLast = oracleState.kCurrent;
            oracleState.totalSupplyLast = oracleState.totalSupplyCurrent;
            oracleState.kCurrent = IUniswapV2Pair(pair).kLast();
            oracleState.totalSupplyCurrent = IUniswapV2Pair(pair).totalSupply();
        }
    }

    /// Retrieve TwapOracleState of pair, updating
    function _getPairState(address pair)
        internal
        returns (TwapOracleState storage oracleState)
    {
        oracleState = pairState[pair];

        (, , uint256 pairLastUpdated) = IUniswapV2Pair(pair).getReserves();
        uint256 timeDelta = pairLastUpdated - oracleState.lastUpdated;

        if (timeDelta > priceUpdateWindow) {
            uint256 newCumul0 = IUniswapV2Pair(pair).price0CumulativeLast();
            oracleState.price0FP =
                (newCumul0 - oracleState.cumulativePrice0) /
                timeDelta;
            oracleState.cumulativePrice0 = newCumul0;
            oracleState.lastUpdated = pairLastUpdated;

            oracleState.kLast = oracleState.kCurrent;
            oracleState.totalSupplyLast = oracleState.totalSupplyCurrent;
            oracleState.kCurrent = IUniswapV2Pair(pair).kLast();
            oracleState.totalSupplyCurrent = IUniswapV2Pair(pair).totalSupply();
        }
    }

    /// Retrieve TwapOracleState of pair, updating
    function getPairState(address pair)
        external
        returns (TwapOracleState memory oracleState)
    {
        return _getPairState(pair);
    }

    /// View amount in peg via twap price
    function viewAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public view virtual override returns (uint256) {
        (address token0, address token1) = sortTokens(token, pegCurrency);
        TwapOracleState memory oracleState = viewPairState(
            bestPairByTokens[token0][token1]
        );
        if (token == token0) {
            return (inAmount * oracleState.price0FP) / FP112;
        } else {
            return (inAmount * FP112) / oracleState.price0FP;
        }
    }

    /// Update twap price and get corresponding peg amount
    function getAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public virtual override returns (uint256) {
        (address token0, address token1) = sortTokens(token, pegCurrency);
        TwapOracleState storage oracleState = _getPairState(
            bestPairByTokens[token0][token1]
        );
        if (token == token0) {
            return (inAmount * oracleState.price0FP) / FP112;
        } else {
            return (inAmount * FP112) / oracleState.price0FP;
        }
    }

    /// Init price via reserves
    function initPairState(address pair)
        public
        returns (TwapOracleState memory)
    {
        TwapOracleState storage oracleState = pairState[pair];

        // To avoid sandwich attacks on this activation call getAmountInPeg once more
        // before releasing to public
        if (oracleState.token0 == address(0)) {
            IUniswapV2Pair uniPair = IUniswapV2Pair(pair);

            (
                uint112 reserve0,
                uint112 reserve1,
                uint256 pairLastUpdated
            ) = uniPair.getReserves();

            uint256 kLast = uniPair.kLast();
            uint256 totalSupply = uniPair.totalSupply();
            pairState[pair] = TwapOracleState({
                token0: uniPair.token0(),
                token1: uniPair.token1(),
                cumulativePrice0: uniPair.price0CumulativeLast(),
                price0FP: (FP112 * reserve1) / reserve0,
                lastUpdated: pairLastUpdated,
                kLast: kLast,
                kCurrent: kLast,
                totalSupplyLast: totalSupply,
                totalSupplyCurrent: totalSupply
            });

            return pairState[pair];
        } else {
            return _getPairState(pair);
        }
    }

    /// Time window after which price is updated
    function setPriceUpdateWindow(uint256 window)
        external
        onlyOwnerExecDisabler
    {
        priceUpdateWindow = window;
        emit ParameterUpdated("price update window", window);
    }

    /// Update reserves of a pair in a time weighted manner
    function getTwapReserves(address pair)
        external
        returns (
            address token0,
            address token1,
            uint256 res0,
            uint256 res1,
            uint256 kLast,
            uint256 totalSupplyLast
        )
    {
        TwapOracleState storage oracleState = _getPairState(pair);

        (res0, res1) = price0FP2Reserves(
            oracleState.kLast,
            oracleState.price0FP
        );
        token0 = oracleState.token0;
        token1 = oracleState.token1;

        kLast = oracleState.kLast;
        totalSupplyLast = oracleState.totalSupplyLast;
    }

    /// view reserves of a pair in a time weighted manner
    function viewTwapReserves(address pair)
        external
        view
        returns (
            address token0,
            address token1,
            uint256 res0,
            uint256 res1,
            uint256 kLast,
            uint256 totalSupplyLast
        )
    {
        TwapOracleState memory oracleState = viewPairState(pair);

        (res0, res1) = price0FP2Reserves(
            oracleState.kLast,
            oracleState.price0FP
        );
        token0 = oracleState.token0;
        token1 = oracleState.token1;

        kLast = oracleState.kLast;
        totalSupplyLast = oracleState.totalSupplyLast;
    }

    /// Convert price to reserves
    function price0FP2Reserves(uint256 k, uint256 price0FP)
        public
        pure
        returns (uint256 res0, uint256 res1)
    {
        // price0FP ~= FP112 * res1 / res0 and k = res1 * res0
        // => k * price0FP = FP112 * res1 / res0 * res1 * res0
        // => k * price0FP / FP112 = res1^2
        // => res0 = sqrt(k * price1FP / FP112) and price1FP = FP112 * 1 / (price0FP / FP112)
        // => res0 = sqrt(k * FP112 / price0FP)
        if (k > price0FP) {
            res0 = sqrt((((k * FP56) / price0FP) * FP56));
        } else {
            // for small k scale up completely first
            res0 = sqrt((k * FP112) / price0FP);
        }
        res1 = k / res0;
    }

    /// @notice Calculates the square root of x, rounding down.
    /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
    ///
    /// Caveats:
    /// - This function does not work with fixed-point numbers.
    ///
    /// @param x The uint256 number for which to calculate the square root.
    /// @return result The result as an uint256.
    function sqrt(uint256 x) internal pure returns (uint256 result) {
        if (x == 0) {
            return 0;
        }

        // Set the initial guess to the closest power of two that is higher than x.
        uint256 xAux = uint256(x);
        result = 1;
        if (xAux >= 0x100000000000000000000000000000000) {
            xAux >>= 128;
            result <<= 64;
        }
        if (xAux >= 0x10000000000000000) {
            xAux >>= 64;
            result <<= 32;
        }
        if (xAux >= 0x100000000) {
            xAux >>= 32;
            result <<= 16;
        }
        if (xAux >= 0x10000) {
            xAux >>= 16;
            result <<= 8;
        }
        if (xAux >= 0x100) {
            xAux >>= 8;
            result <<= 4;
        }
        if (xAux >= 0x10) {
            xAux >>= 4;
            result <<= 2;
        }
        if (xAux >= 0x8) {
            result <<= 1;
        }

        // The operations can never overflow because the result is max 2^127 when it enters this block.
        unchecked {
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1; // Seven iterations should be enough
            uint256 roundedDownResult = x / result;
            return result >= roundedDownResult ? roundedDownResult : result;
        }
    }

    /// returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "Identical address!");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "Zero address!");
    }

    /// Set up oracle based on a pair and whether we prefer this one
    function setOracleSpecificParams(
        address fromToken,
        address toToken,
        address pair,
        bool isBest
    ) external onlyOwnerExec {
        _setOracleSpecificParams(fromToken, toToken, pair, isBest);
        emit ParameterUpdated("oracle specific params", fromToken);
    }

    /// Set up pair, initializing pair state
    /// Note: vulnerable to sandwich attack if lending starts immediately
    function _setOracleSpecificParams(
        address fromToken,
        address toToken,
        address pair,
        bool isBest
    ) internal {
        (address token0, address token1) = sortTokens(fromToken, toToken);
        require(
            IUniswapV2Pair(pair).token0() == token0 &&
                IUniswapV2Pair(pair).token1() == token1,
            "Pair does not match tokens"
        );
        initPairState(pair);

        if (isBest) {
            bestPairByTokens[token0][token1] = pair;
        }
    }

    /// Set up the pair for a twap oracle
    function _setOracleParams(
        address fromToken,
        address toToken,
        bytes calldata data
    ) internal override {
        (address pair, bool isBest) = abi.decode(data, (address, bool));
        _setOracleSpecificParams(fromToken, toToken, pair, isBest);
    }

    /// Encode params for initialization
    function encodeAndCheckOracleParams(
        address tokenFrom,
        address tokenTo,
        address pair,
        bool isBest
    ) external view returns (bool, bytes memory) {
        (address token0, address token1) = sortTokens(tokenFrom, tokenTo);
        TwapOracleState storage state = pairState[pair];
        bool matches = state.token0 == token0 && state.token1 == token1;

        if (isBest) {
            matches = matches && bestPairByTokens[token0][token1] == pair;
        }

        return (matches, abi.encode(pair, isBest));
    }
}
