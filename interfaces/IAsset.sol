// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IAsset {
    function deposit(uint256 trancheId, uint256 tokenAmount) external;

    function registerDepositFor(
        address depositor,
        uint256 trancheId,
        uint256 amount
    ) external;

    function withdraw(
        uint256 trancheId,
        uint256 tokenAmount,
        address recipient
    ) external;

    function burnTranche(
        uint256 trancheId,
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

    function viewValue(uint256 tokenId, address currency)
        external
        view
        returns (uint256);

    function viewColRatioTargetPer10k(uint256 tokenId)
        external
        view
        returns (uint256);

    function collectYieldValueColRatio(
        uint256 tokenId,
        address yieldCurrency,
        address valueCurrency,
        address recipient
    )
        external
        returns (
            uint256 yield,
            uint256 value,
            uint256 colRatio
        );

    function viewYieldValueColRatio(
        uint256 tokenId,
        address yieldCurrency,
        address valueCurrency
    )
        external
        view
        returns (
            uint256 yield,
            uint256 value,
            uint256 colRatio
        );
}
