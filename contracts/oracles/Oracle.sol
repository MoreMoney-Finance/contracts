// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/IOracle.sol";
import "../roles/RoleAware.sol";
import "../roles/DependsOnOracleRegistry.sol";

/// Abstract base for oracles, concerned with parameter init
abstract contract Oracle is IOracle, RoleAware, DependsOnOracleRegistry {
    function setOracleParams(
        address token,
        address pegCurrency,
        bytes calldata data
    ) external override {
        require(
            address(oracleRegistry()) == msg.sender,
            "Not authorized to init oracle"
        );
        _setOracleParams(token, pegCurrency, data);
        emit SubjectUpdated("oracle params", token);
    }

    function _setOracleParams(
        address token,
        address pegCurrency,
        bytes memory data
    ) internal virtual;

    function viewPegAmountAndBorrowable(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) external view override returns (uint256, uint256) {
        return (
            viewAmountInPeg(token, inAmount, pegCurrency),
            oracleRegistry().borrowablePer10ks(token)
        );
    }

    function getPegAmountAndBorrowable(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) external override returns (uint256, uint256) {
        return (
            getAmountInPeg(token, inAmount, pegCurrency),
            oracleRegistry().borrowablePer10ks(token)
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
