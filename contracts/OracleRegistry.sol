// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./OracleAware.sol";
import "./RoleAware.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract OracleRegistry is RoleAware {
    using EnumerableSet for EnumerableSet.AddressSet;
    mapping(address => mapping(address => address)) public tokenOracle;
    mapping(address => mapping(address => EnumerableSet.AddressSet)) _listeners;

    constructor(address _roles) RoleAware(_roles) {}

    function setTokenOracle(
        address token,
        address pegCurrency,
        address oracle
    ) external onlyOwnerExec {
        tokenOracle[token][pegCurrency] = oracle;
    }

    function listenForCurrentOracleUpdates(address token, address pegCurrency)
        external
    {
        require(isOracleListener(msg.sender), "Not allowed to listen");
        _listeners[token][pegCurrency].add(msg.sender);
        OracleAware(msg.sender).newCurrentOracle(token, pegCurrency);
    }
}
