// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./roles/RoleAware.sol";
import "./roles/DependsOnTrancheIDService.sol";
import "./roles/DependsOnIsolatedLending.sol";
import "./roles/DependsOnMetaLending.sol";

import "./roles/DependsOnStableLending2.sol";
import "./StableLending2.sol";
import "./roles/DependsOnStableCoin.sol";

contract MigrateMetaLending is
    DependsOnTrancheIDService,
    DependsOnMetaLending,
    DependsOnStableLending2,
    DependsOnStableCoin,
    ERC721Holder,
    RoleAware
{
    using SafeERC20 for IERC20;

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
            sourceLendingAddress == address(stableLending2()),
            "Not a migratable contract"
        );

        StableLending2 sourceLending2 = StableLending2(sourceLendingAddress);

        // get collateralAmount & repayAmount from sourceLending
        StableLending2.PositionMetadata memory posMeta = sourceLending2
            .viewPositionMetadata(trancheId);

        // mint sufficient stablecoin to repay
        stable.mint(address(this), posMeta.debt);
        sourceLending2.repayAndWithdraw(
            trancheId,
            posMeta.collateralValue,
            posMeta.debt,
            address(this)
        );

        IERC20 colToken = IERC20(posMeta.token);
        uint256 collateralValue = colToken.balanceOf(address(this));

        colToken.safeIncreaseAllowance(targetStrategy, collateralValue);
        MetaLending metaLending = metaLending();
        uint256 newTrancheId = metaLending.mintDepositAndBorrow(
            posMeta.token,
            targetStrategy,
            collateralValue,
            (995 * (posMeta.debt - stable.balanceOf(address(this)))) / 1000,
            address(this)
        );
        metaLending.safeTransferFrom(
            address(this),
            sourceLending2.ownerOf(trancheId),
            newTrancheId
        );

        stable.burn(address(this), stable.balanceOf(address(this)));
    }
}
