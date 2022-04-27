// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./roles/RoleAware.sol";
import "./roles/DependsOnTrancheIDService.sol";
import "./roles/DependsOnIsolatedLending.sol";
import "./roles/DependsOnStableLending.sol";

contract Migrate is DependsOnTrancheIDService, DependsOnIsolatedLending, DependsOnStableLending, RoleAware {
    constructor(address roles) RoleAware(roles) {
        _rolesPlayed.push(TRANCHE_TRANSFERER);
        _rolesPlayed.push(MINTER_BURNER);

    }

    function migratePosition(uint256 trancheId, address targetStrategy) external {
        TrancheIDService tids = trancheIdService();
        address sourceLendingAddress = tids.viewTrancheContractByID(trancheId);
        require (sourceLendingAddress == address(isolatedLending()) || sourceLendingAddress == address(stableLending()), "Not a migratable contract");

        StableLending sourceLending = StableLending(sourceLendingAddress);

        // TODO get collateralAmount & repayAmount from sourceLending
        // mint sufficient stablecoin to repay
        // sourceLending.repayAndWithdraw(trancheId, collateralAmount, repayAmount, address(this));
        
        // TODO update collateralAmount to actual collateral received (by checking balance)
        // and set debt = 999 * (repayAmount - stable.balanceOf(address(this))) / 1000
        

        // uint256 newTrancheId = stableLending2.mintDepositAndBorrow(targetStrategy, collateralAmount, debtAmount, address(this));
        // stableLending2.safeTransferFrom(address(this), sourceLending.ownerOf(trancheId), newTrancheId);
    }
}
