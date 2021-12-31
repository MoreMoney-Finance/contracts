// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Oracle.sol";

/// Converts from one currency to another by a static factor
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

    function setOracleSpecificParams(
        address tokenFrom,
        address tokenTo,
        uint256 tokenFromAmount,
        uint256 tokenToAmount
    ) external onlyOwnerExec {
        _setOracleSpecificParams(
            tokenFrom,
            tokenTo,
            tokenFromAmount,
            tokenToAmount
        );
        emit SubjectUpdated("oracle specific params", tokenFrom);
    }

    function _setOracleSpecificParams(
        address tokenFrom,
        address tokenTo,
        uint256 tokenFromAmount,
        uint256 tokenToAmount
    ) internal {
        scaleConversionFP[tokenFrom][tokenTo] =
            (FP112 * tokenToAmount) /
            tokenFromAmount;
    }

    function _setOracleParams(
        address tokenFrom,
        address tokenTo,
        bytes memory data
    ) internal override {
        (uint256 tokenFromAmount, uint256 tokenToAmount) = abi.decode(
            data,
            (uint256, uint256)
        );
        _setOracleSpecificParams(
            tokenFrom,
            tokenTo,
            tokenFromAmount,
            tokenToAmount
        );
    }

    /// Set conversion factor by presenting one token amount and corresponding
    /// converted amount
    function encodeAndCheckOracleParams(
        address tokenFrom,
        address tokenTo,
        uint256 tokenFromAmount,
        uint256 tokenToAmount
    ) external view returns (bool, bytes memory) {
        bool matches = scaleConversionFP[tokenFrom][tokenTo] ==
            (FP112 * tokenToAmount) / tokenFromAmount;

        return (matches, abi.encode(tokenFromAmount, tokenToAmount));
    }
}
