// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Oracle.sol";
import "../../interfaces/ICurvePool.sol";

contract CurveLPTOracle is Oracle {
    constructor(address _roles) RoleAware(_roles) {}

    uint256 public valueSmoothingPer10k = 7500;
    mapping(address => uint256) public valuePer1e18;

    /// Convert inAmount to peg (view)
    function viewAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public view virtual override returns (uint256) {
        ICurvePool pool = ICurvePool(token);
        require(pegCurrency == pool.coins(0), "Only map prices to coin0");

        uint256 storedVal = valuePer1e18[token];
        if (storedVal == 0) {
            uint256 per1e18 = pool.calc_withdraw_one_coin(1e18, 0);
            return (inAmount * per1e18) / 1e18;
        } else {
            return
                (inAmount *
                    ((valueSmoothingPer10k * storedVal) +
                        (10_000 - valueSmoothingPer10k) *
                        pool.calc_withdraw_one_coin(1e18, 0))) /
                10_000 /
                1e18;
        }
    }

    /// Convert inAmount to peg (updating)
    function getAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public virtual override returns (uint256) {
        uint256 value = viewAmountInPeg(token, inAmount, pegCurrency);
        valuePer1e18[token] = (1e18 * value) / inAmount;
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
    ) internal view override {
        ICurvePool pool = ICurvePool(fromToken);
        require(toToken == pool.coins(0), "Only map prices to coin0");
        // valuePer1e18[fromToken] = pool.calc_withdraw_one_coin(1e18, 0);
    }

    /// Encode params for initialization
    function encodeAndCheckOracleParams(address tokenFrom, address tokenTo)
        external
        view
        returns (bool, bytes memory)
    {
        ICurvePool pool = ICurvePool(tokenFrom);
        require(tokenTo == pool.coins(0), "Only map prices to coin0");
        bool matches = valuePer1e18[tokenFrom] > 0;
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
