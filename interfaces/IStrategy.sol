// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./IAsset.sol";

interface IStrategy is IAsset {
    function acceptMigrationFrom(address strategy, uint256 trancheId) external;

    function mintTranche(
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
