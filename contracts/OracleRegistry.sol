// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./oracles/OracleAware.sol";
import "./roles/RoleAware.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./roles/DependsOnOracleListener.sol";
import "../interfaces/IOracle.sol";

/// Central hub and router for all oracles
contract OracleRegistry is RoleAware, DependsOracleListener {
    using EnumerableSet for EnumerableSet.AddressSet;
    mapping(address => mapping(address => address)) public tokenOracle;
    mapping(address => mapping(address => EnumerableSet.AddressSet))
        internal _listeners;
    mapping(address => uint256) public borrowablePer10ks;

    constructor(address _roles) RoleAware(_roles) {
        _charactersPlayed.push(ORACLE_REGISTRY);
    }

    function setBorrowable(address token, uint256 borrowablePer10k)
        external
        onlyOwnerExec
    {
        borrowablePer10ks[token] = borrowablePer10k;
        emit SubjectParameterUpdated("borrowable", token, borrowablePer10k);
    }

    /// Initialize oracle for a specific token
    function setOracleParams(
        address token,
        address pegCurrency,
        address oracle,
        uint256 borrowablePer10k,
        bool primary,
        bytes calldata data
    ) external onlyOwnerExecActivator {
        borrowablePer10ks[token] = borrowablePer10k;
        IOracle(oracle).setOracleParams(
            token,
            pegCurrency,
            data
        );

        // only overwrite oracle and update listeners if update is for a primary
        // or there is no pre-existing oracle
        address previousOracle = tokenOracle[token][pegCurrency];
        if (previousOracle == address(0) || primary) {
            tokenOracle[token][pegCurrency] = oracle;

            EnumerableSet.AddressSet storage listeners = _listeners[token][
                pegCurrency
            ];
            for (uint256 i; listeners.length() > i; i++) {
                OracleAware(listeners.at(i)).newCurrentOracle(
                    token,
                    pegCurrency
                );
            }
        }

        emit SubjectParameterUpdated("borrowable", token, borrowablePer10k);
    }

    /// Which oracle contract is currently responsible for a token is cached
    /// This updates
    function listenForCurrentOracleUpdates(address token, address pegCurrency)
        external
        returns (address)
    {
        require(isOracleListener(msg.sender), "Not allowed to listen");
        _listeners[token][pegCurrency].add(msg.sender);
        return tokenOracle[token][pegCurrency];
    }

    /// View converted value in currently registered oracle
    function viewAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public view returns (uint256) {
        return
            IOracle(tokenOracle[token][pegCurrency]).viewAmountInPeg(
                token,
                inAmount,
                pegCurrency
            );
    }

    /// View amounts for an array of tokens
    function viewAmountsInPeg(
        address[] calldata tokens,
        uint256[] calldata inAmounts,
        address pegCurrency
    ) external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](inAmounts.length);
        for (uint256 i; inAmounts.length > i; i++) {
            result[i] = viewAmountInPeg(tokens[i], inAmounts[i], pegCurrency);
        }
        return result;
    }

    /// Update converted value in currently registered oracle
    function getAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public returns (uint256) {
        return
            IOracle(tokenOracle[token][pegCurrency]).getAmountInPeg(
                token,
                inAmount,
                pegCurrency
            );
    }

    /// Get amounts for an array of tokens
    function getAmountsInPeg(
        address[] calldata tokens,
        uint256[] calldata inAmounts,
        address pegCurrency
    ) external returns (uint256[] memory) {
        uint256[] memory result = new uint256[](inAmounts.length);
        for (uint256 i; inAmounts.length > i; i++) {
            result[i] = getAmountInPeg(tokens[i], inAmounts[i], pegCurrency);
        }
        return result;
    }
}
