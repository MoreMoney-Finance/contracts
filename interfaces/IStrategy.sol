// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./IAsset.sol";

interface IStrategy is IAsset {
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

    function isActive() external returns (bool);

    function migrateAllTo(address destination) external;

    function trancheToken(uint256 trancheId)
        external
        view
        returns (address token);

    function viewTargetCollateralAmount(uint256 trancheId)
        external
        view
        returns (uint256);
}
