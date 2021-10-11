// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./TrancheIDAware.sol";
import "./OracleRegistry.sol";
import "../interfaces/IOracle.sol";

abstract contract OracleAware is TrancheIDAware {
    mapping(address => mapping(address => address)) public _oracleCache;

    function newCurrentOracle(address token, address pegCurrency) external {
        if (_oracleCache[token][pegCurrency] != address(0)) {
            // make sure we don't init cache without listening
            _oracleCache[token][pegCurrency] = OracleRegistry(oracleRegistry())
                .tokenOracle(token, pegCurrency);
        }
    }

    function _listenForOracle(address token, address pegCurrency)
        public
        returns (address oracle)
    {
        if (_oracleCache[token][pegCurrency] == address(0)) {
            OracleRegistry(oracleRegistry()).listenForCurrentOracleUpdates(
                token,
                pegCurrency
            );
            oracle = OracleRegistry(oracleRegistry()).tokenOracle(
                token,
                pegCurrency
            );
            _oracleCache[token][pegCurrency] = oracle;
        }
    }

    function _viewValueColRatio(
        address token,
        uint256 amount,
        address valueCurrency
    ) internal view virtual returns (uint256 value, uint256 colRatio) {
        return
            IOracle(_oracleCache[token][valueCurrency])
                .viewPegAmountAndColRatio(token, amount, valueCurrency);
    }

    function _getValueColRatio(
        address token,
        uint256 amount,
        address valueCurrency
    ) internal virtual returns (uint256 value, uint256 colRatio) {
        address oracle = _oracleCache[token][valueCurrency];
        if (oracle == address(0)) {
            oracle = _listenForOracle(token, valueCurrency);
        }

        return
            IOracle(oracle).getPegAmountAndColRatio(
                token,
                amount,
                valueCurrency
            );
    }
}
