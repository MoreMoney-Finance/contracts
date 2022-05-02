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
        (
            uint256 collateralValue,
            address token,
            uint256 collateral,
            uint256 debt,
            uint256 yield
        ) = sourceLending.viewPositionMetadata(trancheId);
        uint256 repayAmount = debt > yield ? debt - yield : 0;
        // mint sufficient stablecoin to repay
        stable.mint(address(this), repayAmount);
        sourceLending.repayAndWithdraw(
            trancheId,
            collateralValue,
            repayAmount,
            address(this)
        );

        collateralValue = IERC20(token).balanceOf(address(this));

        // TODO update collateralValue to actual collateral received (by checking current balance in collateral token -- TODO get collateral token for position)
        uint256 debt2 = (999 *
            (repayAmount - stable.balanceOf(address(this)))) / 1000;

        StableLending2 lending2 = stableLending2();
        uint256 newTrancheId = lending2.mintDepositAndBorrow(
            token,
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
