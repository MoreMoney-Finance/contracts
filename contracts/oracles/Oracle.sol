// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/IOracle.sol";
import "../roles/RoleAware.sol";
import "../roles/DependsOnOracleRegistry.sol";

/// Abstract base for oracles, concerned with parameter init
abstract contract Oracle is IOracle, RoleAware, DependsOnOracleRegistry {
    mapping(address => uint256) public borrowablePer10ks;

    function setBorrowable(address lpt, uint256 borrowablePer10k)
        external
        onlyOwnerExec
    {
        borrowablePer10ks[lpt] = borrowablePer10k;
    }

    function setOracleParams(
        address token,
        address pegCurrency,
        uint256 borrowablePer10k,
        bytes calldata data
    ) external override {
        require(
            address(oracleRegistry()) == msg.sender,
            "Not authorized to init oracle"
        );
        borrowablePer10ks[token] = borrowablePer10k;
        _setOracleParams(token, pegCurrency, data);
    }

    function _setOracleParams(
        address token,
        address pegCurrency,
        bytes calldata data
    ) internal virtual;

    function viewPegAmountAndBorrowable(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) external view override returns (uint256, uint256) {
        return (
            viewAmountInPeg(token, inAmount, pegCurrency),
            borrowablePer10ks[token]
        );
    }

    function getPegAmountAndBorrowable(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) external override returns (uint256, uint256) {
        return (
            getAmountInPeg(token, inAmount, pegCurrency),
            borrowablePer10ks[token]
        );
    }

    function viewAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public view virtual override returns (uint256);

    function getAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public virtual override returns (uint256);
}
