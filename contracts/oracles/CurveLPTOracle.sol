// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Oracle.sol";
import "../../interfaces/ICurvePool.sol";

contract CurveLPTOracle is Oracle {
    constructor(address _roles) RoleAware(_roles) {}

    uint256 public valueSmoothingPer10k = 7500;

    struct OracleState {
        uint256 lastValuePer1e18;
        uint256 valuePer1e18;
        uint256 lastUpdated;
    }

    mapping(address => OracleState) public oracleState;

    /// Convert inAmount to peg (view)
    function viewAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public view virtual override returns (uint256) {
        ICurvePool pool = ICurvePool(token);
        require(pegCurrency == pool.coins(0), "Only map prices to coin0");
        OracleState storage state = oracleState[token];

        if (state.lastValuePer1e18 == 0) {
            uint256 per1e18 = pool.calc_withdraw_one_coin(1e18, 0);
            return (inAmount * per1e18) / 1e18;
        } else {
            return (inAmount * state.lastValuePer1e18) / 1e18;
        }
    }

    /// Convert inAmount to peg (updating)
    function getAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public virtual override returns (uint256) {
        uint256 value = viewAmountInPeg(token, inAmount, pegCurrency);
        OracleState storage state = oracleState[token];

        if (block.timestamp - state.lastUpdated > 5 minutes) {
            ICurvePool pool = ICurvePool(token);

            state.lastUpdated = block.timestamp;
            state.lastValuePer1e18 = state.valuePer1e18;
            state.valuePer1e18 =
                (valueSmoothingPer10k * state.valuePer1e18) +
                ((10_000 - valueSmoothingPer10k) *
                    pool.calc_withdraw_one_coin(1e18, 0)) /
                10_000;
        }

        return value;
    }

    /// Set params
    function setOracleSpecificParams(address fromToken, address toToken)
        external
        onlyOwnerExec
    {
        bytes memory data = "";
        _setOracleParams(fromToken, toToken, data);
    }

    /// Set params
    function _setOracleParams(
        address fromToken,
        address toToken,
        bytes memory
    ) internal override {
        ICurvePool pool = ICurvePool(fromToken);
        require(toToken == pool.coins(0), "Only map prices to coin0");
        uint256 per1e18 = pool.calc_withdraw_one_coin(1e18, 0);
        oracleState[fromToken] = OracleState({
            lastUpdated: block.timestamp,
            lastValuePer1e18: per1e18,
            valuePer1e18: per1e18
        });
    }

    /// Encode params for initialization
    function encodeAndCheckOracleParams(address tokenFrom, address tokenTo)
        external
        view
        returns (bool, bytes memory)
    {
        ICurvePool pool = ICurvePool(tokenFrom);
        require(tokenTo == pool.coins(0), "Only map prices to coin0");
        bool matches = oracleState[tokenFrom].valuePer1e18 > 0 &&
            oracleState[tokenFrom].lastValuePer1e18 > 0;
        return (matches, "");
    }

    function setValueSmoothingPer10k(uint256 smoothingPer10k)
        external
        onlyOwnerExec
    {
        require(10_000 >= smoothingPer10k, "Needs to be less than 10k");
        valueSmoothingPer10k = smoothingPer10k;
        emit ParameterUpdated("value smoothing", smoothingPer10k);
    }
}
