// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Executor.sol";
import "../roles/DependsOnIsolatedLending.sol";
import "../roles/DependsOnOracleRegistry.sol";
import "../Strategy.sol";

contract OracleActivation is
    Executor,
    DependsOnOracleRegistry
{
    address public immutable oracle;
    address[] public tokens;
    address[] public pegCurrencies;
    uint256[] public colRatios;
    bytes[] public data;    

    constructor(
        address _oracle,
        address[] memory _tokens,
        address[] memory _pegCurrencies,
        uint256[] memory _colRatios,
        bytes[] memory _data,
        address _roles
    ) RoleAware(_roles) {
        tokens = _tokens;
        pegCurrencies = _pegCurrencies;
        data = _data;
        oracle = _oracle;
        colRatios = _colRatios;
    }

    function execute() external override {
        uint256 len = tokens.length;

        for (uint256 i; len > i; i++) {
            oracleRegistry().setOracleParams(tokens[i], pegCurrencies[i], oracle, colRatios[i], data[i]);
        }

        delete tokens;
        delete pegCurrencies;
        delete data;
        selfdestruct(payable(tx.origin));
    }
}
