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

        // sourceLending.repayAndWithdraw(trancheId, collateralAmount, repayAmount, address(this));
        // todo insert

        // stableLending2.mintDepositAndBorrow(targetStrategy, debtAmount)
    }
}