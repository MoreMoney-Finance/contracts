// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../roles/RoleAware.sol";
import "../roles/DependsOnTrancheIDService.sol";

import "../roles/DependsOnTrancheIDService.sol";
import "../roles/DependsOnMetaLending.sol";
import "../roles/DependsOnIsolatedLending.sol";

contract BigMigrateMetaLending is
    RoleAware,
    DependsOnTrancheIDService,
    DependsOnStableCoin,
    DependsOnMetaLending,
    ERC721Holder
{
    using SafeERC20 for IERC20;

    constructor(address roles) RoleAware(roles) {
        _rolesPlayed.push(TRANCHE_TRANSFERER);
        _rolesPlayed.push(MINTER_BURNER);
    }

    /// Migrate assets from one strategy to another, collecting yield if any
    function migrateStrategy(
        uint256 trancheId,
        address destination,
        address,
        address
    )
        external
        returns (
            address,
            uint256,
            uint256
        )
    {
        MetaLending targetLending = metaLending();
        MetaLending sourceLending;
        uint256 newTrancheId;

        // ugly stuff happens here to not run out of stack
        {
            Stablecoin stable = stableCoin();
            {
                TrancheIDService tids = trancheIdService();

                address sourceLendingAddress = tids.viewTrancheContractByID(
                    trancheId
                );
                require(
                    sourceLendingAddress == address(metaLending()),
                    "Not a migratable contract"
                );

                sourceLending = MetaLending(sourceLendingAddress);

                require(
                    sourceLending.isAuthorized(msg.sender, trancheId),
                    "not authorized to migrate"
                );
            }

            // get collateralAmount & repayAmount from sourceLending
            MetaLending.PositionMetadata memory posMeta = sourceLending
                .viewPositionMetadata(trancheId);

            // mint sufficient stablecoin to repay
            stable.mint(address(this), posMeta.debt);
            sourceLending.repayAndWithdraw(
                trancheId,
                posMeta.collateralValue,
                posMeta.debt,
                address(this)
            );

            {
                uint256 collateralValue = IERC20(posMeta.token).balanceOf(
                    address(this)
                );

                IERC20(posMeta.token).safeIncreaseAllowance(
                    destination,
                    collateralValue
                );
                (, uint256 feePer10k, , ) = targetLending.assetConfigs(
                    posMeta.token
                );
                newTrancheId = targetLending.mintDepositAndBorrow(
                    posMeta.token,
                    destination,
                    collateralValue,
                    ((10_000 - feePer10k) *
                        (posMeta.debt - stable.balanceOf(address(this)))) /
                        10_000,
                    address(this)
                );

                stable.burn(address(this), stable.balanceOf(address(this)));
            }
        }
        targetLending.safeTransferFrom(
            address(this),
            sourceLending.ownerOf(trancheId),
            newTrancheId
        );

        return (address(0), newTrancheId, 0);
    }
}
