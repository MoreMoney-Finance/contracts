// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./roles/RoleAware.sol";
import "./roles/DependsOnTrancheIDService.sol";
import "./roles/DependsOnIsolatedLending.sol";
import "./roles/DependsOnStableLending.sol";
import "./roles/DependsOnStableLending2.sol";
import "./StableLending2.sol";
import "./roles/DependsOnStableCoin.sol";

contract Migrate is
    DependsOnTrancheIDService,
    DependsOnIsolatedLending,
    DependsOnStableLending,
    DependsOnStableLending2,
    DependsOnStableCoin,
    RoleAware
{
    constructor(address roles) RoleAware(roles) {
        _rolesPlayed.push(TRANCHE_TRANSFERER);
        _rolesPlayed.push(MINTER_BURNER);
    }

    function migratePosition(uint256 trancheId, address targetStrategy)
        external
    {
        TrancheIDService tids = trancheIdService();
        Stablecoin stable = stableCoin();
        address sourceLendingAddress = tids.viewTrancheContractByID(trancheId);
        require(
            sourceLendingAddress == address(isolatedLending()) ||
                sourceLendingAddress == address(stableLending()),
            "Not a migratable contract"
        );

        StableLending sourceLending = StableLending(sourceLendingAddress);

        // get collateralAmount & repayAmount from sourceLending
        StableLending.PositionMetadata memory posMeta = sourceLending
            .viewPositionMetadata(trancheId);

        // mint sufficient stablecoin to repay
        stable.mint(address(this), posMeta.debt);
        sourceLending.repayAndWithdraw(
            trancheId,
            posMeta.collateralValue,
            posMeta.debt,
            address(this)
        );

        uint256 collateralValue = IERC20(posMeta.token).balanceOf(
            address(this)
        );

        // update collateralValue to actual collateral received (by checking current balance in collateral token -- TODO get collateral token for position)
        uint256 debt2 = (999 *
            (posMeta.debt - stable.balanceOf(address(this)))) / 1000;

        StableLending2 lending2 = stableLending2();
        uint256 newTrancheId = lending2.mintDepositAndBorrow(
            posMeta.token,
            targetStrategy,
            collateralValue,
            debt2,
            address(this)
        );
        lending2.safeTransferFrom(
            address(this),
            sourceLending.ownerOf(trancheId),
            newTrancheId
        );
    }
}