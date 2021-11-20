// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./IAsset.sol";

interface IStrategy is IAsset {
    enum YieldType {
        REPAYING,
        COMPOUNDING,
        NOYIELD
    }

    struct StrategyMetadata {
        address strategy;
        address token;
        uint256 APF;
        uint256 totalCollateral;
        uint256 borrowablePer10k;
        uint256 valuePer1e18;
        bytes32 strategyName;
        uint256 tvl;
        uint256 harvestBalance2Tally;
        YieldType yieldType;
        uint256 stabilityFee;
    }

    function acceptMigration(
        uint256 trancheId,
        address sourceStrategy,
        address tokenContract,
        uint256 tokenId,
        uint256 amount
    ) external;

    function registerMintTranche(
        address minter,
        uint256 trancheId,
        address assetToken,
        uint256 assetTokenId,
        uint256 assetAmount
    ) external;

    function registerDepositFor(
        address depositor,
        uint256 trancheId,
        uint256 amount,
        address yieldRecipient
    ) external;

    function strategyName() external view returns (bytes32);

    function isActive() external returns (bool);

    function migrateAllTo(address destination) external;

    function trancheToken(uint256 trancheId)
        external
        view
        returns (address token);

    function trancheTokenID(uint256 trancheId)
        external
        view
        returns (uint256 tokenId);

    function viewTargetCollateralAmount(uint256 trancheId)
        external
        view
        returns (uint256);

    function approvedToken(address token) external view returns (bool);

    function viewAllApprovedTokens() external view returns (address[] memory);

    function approvedTokensCount() external view returns (uint256);

    function viewStrategyMetadata(address token)
        external
        view
        returns (StrategyMetadata memory);

    function viewAllStrategyMetadata()
        external
        view
        returns (StrategyMetadata[] memory);

    function viewAPF(address token) external view returns (uint256);

    function viewValueBorrowable(uint256 trancheId, address valueCurrency)
        external
        view
        returns (uint256, uint256);

    function yieldType() external view returns (YieldType);

    function harvestPartially(address token) external;

    function viewValue(uint256 tokenId, address currency)
        external
        view
        returns (uint256);

    function yieldCurrency() external view returns (address);
}
