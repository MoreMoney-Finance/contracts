// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Oracle.sol";
import "./OracleAware.sol";

contract ProxyOracle is Oracle, OracleAware {
    uint256 constant FP112 = 2**112;

    constructor(address _roles) RoleAware(_roles) {}

    mapping(address => mapping(address => address)) public valueProxy;

    function viewAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public view virtual override returns (uint256) {
        address proxy = valueProxy[token][pegCurrency];
        uint256 proxyAmount = _viewValue(token, inAmount, proxy);
        return _viewValue(proxy, proxyAmount, pegCurrency);
    }

    function getAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public virtual override returns (uint256) {
        address proxy = valueProxy[token][pegCurrency];
        uint256 proxyAmount = _getValue(token, inAmount, proxy);
        return _getValue(proxy, proxyAmount, pegCurrency);
    }

    function setOracleSpecificParams(
        address fromToken,
        address toToken,
        address proxy
    ) external onlyOwnerExec {
        valueProxy[fromToken][toToken] = proxy;
    }

    function _setOracleSpecificParams(
        address fromToken,
        address toToken,
        address proxy
    ) internal {
        valueProxy[fromToken][toToken] = proxy;
    }

    function _setOracleParams(
        address fromToken,
        address toToken,
        bytes calldata data
    ) internal override {
        _setOracleSpecificParams(
            fromToken,
            toToken,
            abi.decode(data, (address))
        );
    }

    function encodeAndCheckOracleParams(
        address tokenFrom,
        address tokenTo,
        address proxy
    ) external view returns (bool, bytes memory) {
        bool matches = valueProxy[tokenFrom][tokenTo] == proxy;
        return (matches, abi.encode(proxy));
    }
}
