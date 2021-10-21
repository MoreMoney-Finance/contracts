// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./oracles/OracleAware.sol";
import "./roles/RoleAware.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./roles/DependsOnOracleListener.sol";
import "../interfaces/IOracle.sol";

contract OracleRegistry is RoleAware, DependsOracleListener {
    using EnumerableSet for EnumerableSet.AddressSet;
    mapping(address => mapping(address => address)) public tokenOracle;
    mapping(address => mapping(address => EnumerableSet.AddressSet)) _listeners;

    constructor(address _roles) RoleAware(_roles) {
        _charactersPlayed.push(ORACLE_REGISTRY);
    }

    function setOracleParams(
        address token,
        address pegCurrency,
        address oracle,
        uint256 colRatio,
        bytes calldata data
    ) external onlyOwnerExec {
        tokenOracle[token][pegCurrency] = oracle;
        IOracle(oracle).setOracleParams(token, pegCurrency, colRatio, data);
    }

    function listenForCurrentOracleUpdates(address token, address pegCurrency)
        external
    {
        require(isOracleListener(msg.sender), "Not allowed to listen");
        _listeners[token][pegCurrency].add(msg.sender);
        OracleAware(msg.sender).newCurrentOracle(token, pegCurrency);
    }
}
