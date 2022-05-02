// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./roles/RoleAware.sol";
import "./roles/DependsOnTrancheIDService.sol";
import "./roles/DependsOnIsolatedLending.sol";
import "./roles/DependsOnStableLending.sol";
import "./Roles/DependsOnStableCoin.sol";

contract Migrate is DependsOnTrancheIDService, DependsOnIsolatedLending, DependsOnStableLending, DependsOnStableCoin, RoleAware {
    constructor(address roles) RoleAware(roles) {
        _rolesPlayed.push(TRANCHE_TRANSFERER);
        _rolesPlayed.push(MINTER_BURNER);

    }

    function migratePosition(uint256 trancheId, address targetStrategy) external {
        TrancheIDService tids = trancheIdService();
        Stablecoin stable = stableCoin();
        address sourceLendingAddress = tids.viewTrancheContractByID(trancheId);
        require (sourceLendingAddress == address(isolatedLending()) || sourceLendingAddress == address(stableLending()), "Not a migratable contract");

        StableLending sourceLending = StableLending(sourceLendingAddress);

        // TODO get collateralAmount & repayAmount from sourceLending (collateral and debt associated with position, you can follow the way we get position metadata on frontend)

        // mint sufficient stablecoin to repay
        // stable.mint(address(this), repayAmount);
        // sourceLending.repayAndWithdraw(trancheId, collateralAmount, repayAmount, address(this));
        
        // TODO update collateralAmount to actual collateral received (by checking current balance in collateral token -- TODO get collateral token for position)
        // uint256 debt = 999 * (repayAmount - stable.balanceOf(address(this))) / 1000
        
        // TODO Make sure you have created & imported DependsOnStableLending2 to run the following:
        // StableLending2 ending2 = stableLending2();
        // uint256 newTrancheId = lending2.mintDepositAndBorrow(targetStrategy, collateralAmount, debt, address(this));
        // lending2.safeTransferFrom(address(this), sourceLending.ownerOf(trancheId), newTrancheId);
    }
}
