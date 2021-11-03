// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../TrancheIDAware.sol";
import "../OracleRegistry.sol";
import "../../interfaces/IOracle.sol";
import "../roles/DependsOnOracleRegistry.sol";

abstract contract OracleAware is RoleAware, DependsOnOracleRegistry {
    mapping(address => mapping(address => address)) public _oracleCache;

    constructor() {
        _rolesPlayed.push(ORACLE_LISTENER);
    }

    function newCurrentOracle(address token, address pegCurrency) external {
        if (_oracleCache[token][pegCurrency] != address(0)) {
            // make sure we don't init cache without listening
            _oracleCache[token][pegCurrency] = oracleRegistry().tokenOracle(
                token,
                pegCurrency
            );
        }
    }

    function _listenForOracle(address token, address pegCurrency)
        public
        returns (address oracle)
    {
        if (_oracleCache[token][pegCurrency] == address(0)) {
            oracleRegistry().listenForCurrentOracleUpdates(token, pegCurrency);
            oracle = oracleRegistry().tokenOracle(token, pegCurrency);
            _oracleCache[token][pegCurrency] = oracle;
        }
    }

    function _viewValue(
        address token,
        uint256 amount,
        address valueCurrency
    ) internal view virtual returns (uint256 value) {
        address oracle = _oracleCache[token][valueCurrency];
        if (oracle == address(0)) {
            oracle = oracleRegistry().tokenOracle(token, valueCurrency);
        }
        return IOracle(oracle).viewAmountInPeg(token, amount, valueCurrency);
    }

    function _getValue(
        address token,
        uint256 amount,
        address valueCurrency
    ) internal virtual returns (uint256 value) {
        address oracle = _oracleCache[token][valueCurrency];
        if (oracle == address(0)) {
            oracle = _listenForOracle(token, valueCurrency);
        }

        return IOracle(oracle).getAmountInPeg(token, amount, valueCurrency);
    }

    function _viewValueBorrowable(
        address token,
        uint256 amount,
        address valueCurrency
    ) internal view virtual returns (uint256 value, uint256 borrowablePer10k) {
        address oracle = _oracleCache[token][valueCurrency];
        if (oracle == address(0)) {
            oracle = oracleRegistry().tokenOracle(token, valueCurrency);
        }
        (value, borrowablePer10k) = IOracle(oracle).viewPegAmountAndBorrowable(
            token,
            amount,
            valueCurrency
        );

        require(borrowablePer10k > 0, "Uninitialized borrowable per 10k");
    }

    function _getValueBorrowable(
        address token,
        uint256 amount,
        address valueCurrency
    ) internal virtual returns (uint256 value, uint256 borrowablerPer10k) {
        address oracle = _oracleCache[token][valueCurrency];
        if (oracle == address(0)) {
            oracle = _listenForOracle(token, valueCurrency);
        }

        (value, borrowablerPer10k) = IOracle(oracle).getPegAmountAndBorrowable(
            token,
            amount,
            valueCurrency
        );

        require(borrowablerPer10k > 0, "Uninitialized borrowable per 10k");
    }
}
