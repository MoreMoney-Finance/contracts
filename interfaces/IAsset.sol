// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IAsset {
    function withdraw(
        uint256 trancheId,
        uint256 tokenAmount,
        address yieldToken,
        address recipient
    ) external;

    function migrateStrategy(
        uint256 trancheId,
        address targetStrategy,
        address yieldToken,
        address yieldRecipient
    )
        external
        returns (
            address token,
            uint256 tokenId,
            uint256 targetAmount
        );

    function collectYield(
        uint256 tokenId,
        address currency,
        address recipient
    ) external returns (uint256);

    function viewYield(uint256 tokenId, address currency)
        external
        view
        returns (uint256);

    function viewBorrowable(uint256 tokenId) external view returns (uint256);

    function collectYieldValueBorrowable(
        uint256 tokenId,
        address yieldCurrency,
        address valueCurrency,
        address recipient
    )
        external
        returns (
            uint256 yield,
            uint256 value,
            uint256 borrowablePer10k
        );

    function viewYieldValueBorrowable(
        uint256 tokenId,
        address yieldCurrency,
        address valueCurrency
    )
        external
        view
        returns (
            uint256 yield,
            uint256 value,
            uint256 borrowablePer10k
        );
}
