// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IOracle {
    function viewAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) external view returns (uint256);

    function getAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) external returns (uint256);

    function viewPegAmountAndBorrowable(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) external view returns (uint256, uint256);

    function getPegAmountAndBorrowable(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) external returns (uint256, uint256);

    function setOracleParams(
        address token,
        address pegCurrency,
        uint256 borrowable,
        bytes calldata data
    ) external;
}

// TODO: compatible with NFTs
