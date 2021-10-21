// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Oracle.sol";

contract EquivalentScaledOracle is Oracle {
    uint256 constant FP112 = 2**112;

    constructor(address _roles) RoleAware(_roles) {}

    mapping(address => mapping(address => uint256)) public scaleConversionFP;

    function viewAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public view virtual override returns (uint256) {
        return (scaleConversionFP[token][pegCurrency] * inAmount) / FP112;
    }

    function getAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public view virtual override returns (uint256) {
        return viewAmountInPeg(token, inAmount, pegCurrency);
    }

    function setScaleConversion(
        address tokenFrom,
        address tokenTo,
        uint256 tokenFromAmount,
        uint256 tokenToAmount
    ) external onlyOwnerExec {
        scaleConversionFP[tokenFrom][tokenTo] =
            (FP112 * tokenToAmount) /
            tokenFromAmount;
    }
}