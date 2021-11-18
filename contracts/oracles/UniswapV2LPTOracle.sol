// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IOracle.sol";
import "./Oracle.sol";
import "./OracleAware.sol";
import "./TwapOracle.sol";
import "../roles/DependsOnTwapOracle.sol";

/// Calculates value of LPT based on the reserves they represent, via the
/// Value of their twap-tracked reserves
contract UniswapV2LPTOracle is Oracle, OracleAware, DependsonTwapOracle {
    mapping(address => address) public singleSideValuation;

    constructor(address _roles) RoleAware(_roles) {}

    /// View value of LPT via its reserves
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
            ,
            uint256 totalSupplyLast
        ) = twapOracle().viewTwapReserves(token);

        address singleSideToken = singleSideValuation[token];
        uint256 totalResVal;
        if (singleSideToken == token0) {
            uint256 resVal0 = _viewValue(token0, reserve0, pegCurrency);
            totalResVal = resVal0 * 2;
        } else if (singleSideToken == token1) {
            uint256 resVal1 = _viewValue(token1, reserve1, pegCurrency);
            totalResVal = resVal1 * 2;
        } else {
            uint256 resVal0 = _viewValue(token0, reserve0, pegCurrency);
            uint256 resVal1 = _viewValue(token1, reserve1, pegCurrency);
            totalResVal = resVal0 + resVal1;
        }
        return (inAmount * totalResVal) / totalSupplyLast;
    }

    /// Get value of LPT via its reserves
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
            ,
            uint256 totalSupplyLast
        ) = twapOracle().getTwapReserves(token);

        address singleSideToken = singleSideValuation[token];
        uint256 totalResVal;
        if (singleSideToken == token0) {
            uint256 resVal0 = _getValue(token0, reserve0, pegCurrency);
            totalResVal = resVal0 * 2;
        } else if (singleSideToken == token1) {
            uint256 resVal1 = _getValue(token1, reserve1, pegCurrency);
            totalResVal = resVal1 * 2;
        } else {
            uint256 resVal0 = _getValue(token0, reserve0, pegCurrency);
            uint256 resVal1 = _getValue(token1, reserve1, pegCurrency);
            totalResVal = resVal0 + resVal1;
        }
        return (inAmount * totalResVal) / totalSupplyLast;
    }

    /// Set single side token (if any)
    function setOracleSpecificParams(
        address token,
        address pegCurrency,
        address singleSideToken
    ) external onlyOwnerExec {
        _setOracleSpecificParams(token, pegCurrency, singleSideToken);
    }

    /// Set single side token (if any)
    function _setOracleSpecificParams(
        address token,
        address pegCurrency,
        address singleSideToken
    ) internal {
        TwapOracle.TwapOracleState memory pairState = twapOracle()
            .initPairState(token);

        require(
            singleSideToken == pairState.token0 ||
                singleSideToken == pairState.token1 ||
                singleSideToken == address(0),
            "Not a valid single side token"
        );
        if (singleSideToken != pairState.token0) {
            require(
                _getValue(pairState.token1, 1e18, pegCurrency) > 0,
                "Constituent oracle for token1 not set up"
            );
        }
        if (singleSideToken != pairState.token1) {
            require(
                _getValue(pairState.token0, 1e18, pegCurrency) > 0,
                "Constituent oracle for token0 not set up"
            );
        }
        singleSideValuation[token] = singleSideToken;
    }

    /// Set single side token (if any)
    function _setOracleParams(
        address token,
        address pegCurrency,
        bytes calldata data
    ) internal override {
        address singleSideToken = abi.decode(data, (address));
        _setOracleSpecificParams(token, pegCurrency, singleSideToken);
    }

    /// Encode params for initialization
    function encodeAndCheckOracleParams(
        address token,
        address,
        address singleSideToken
    ) external view returns (bool, bytes memory) {
        TwapOracle.TwapOracleState memory pairState = twapOracle()
            .viewPairState(token);
        bool matches = pairState.token0 != address(0) &&
            singleSideValuation[token] == singleSideToken;

        return (matches, abi.encode(singleSideToken));
    }
}
