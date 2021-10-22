// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./IAsset.sol";

interface IStrategy is IAsset {
    struct StrategyMetadata {
        address strategy;
        address token;
        uint256 APF;
        uint256 totalCollateral;
        uint256 colRatio;
        uint256 valuePer1e18;
        bytes32 strategyName;
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
}
