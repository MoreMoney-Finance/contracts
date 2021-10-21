// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/IOracle.sol";
import "../roles/RoleAware.sol";
import "../roles/DependsOnOracleRegistry.sol";

abstract contract Oracle is IOracle, RoleAware, DependsOnOracleRegistry {
    mapping(address => uint256) public colRatios;

    function setColRatio(address lpt, uint256 colRatio) external onlyOwnerExec {
        colRatios[lpt] = colRatio;
    }

    function setOracleParams(
        address token,
        address,
        uint256 colRatio
    ) external override {
        require(
            address(oracleRegistry()) == msg.sender,
            "Not authorized to init oracle"
        );
        colRatios[token] = colRatio;
    }

    function viewPegAmountAndColRatio(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) external view override returns (uint256, uint256) {
        return (
            viewAmountInPeg(token, inAmount, pegCurrency),
            colRatios[token]
        );
    }

    function getPegAmountAndColRatio(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) external override returns (uint256, uint256) {
        return (getAmountInPeg(token, inAmount, pegCurrency), colRatios[token]);
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
