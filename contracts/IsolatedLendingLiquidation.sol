// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./oracles/OracleAware.sol";
import "./roles/RoleAware.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IsolatedLending.sol";
import "./roles/DependsOnStableCoin.sol";
import "./roles/DependsOnIsolatedLending.sol";
import "./roles/DependsOnFeeRecipient.sol";

contract IsolatedLendingLiquidation is
    RoleAware,
    DependsOnStableCoin,
    DependsOnIsolatedLending,
    DependsOnFeeRecipient
{
    int256 public liquidationSharePer10k = 300;
    uint256 public pendingFees;

    constructor(address _roles) RoleAware(_roles) {
        _rolesPlayed.push(LIQUIDATOR);
        _rolesPlayed.push(FUND_TRANSFERER);
    }

    function liquidatable(uint256 trancheId) public view returns (bool) {
        address stable = address(stableCoin());
        IsolatedLending lending = isolatedLending();
        (uint256 yield, uint256 value, uint256 borrowablePer10k) = lending
            .viewYieldValueBorrowable(trancheId, stable, stable);
        uint256 debt = lending.trancheDebt(trancheId);

        uint256 thresholdPer10k = lending.borrowable2LiqThresh(
            borrowablePer10k
        );

        // value / debt > 10k / threshold
        return (value + yield) * thresholdPer10k > 10_000 * debt;
    }

    function getLiquidatability(uint256 trancheId)
        public
        returns (bool, int256)
    {
        IsolatedLending lending = isolatedLending();
        address stable = address(stableCoin());
        (, uint256 value, uint256 borrowablePer10k) = lending
            .collectYieldValueBorrowable(
                trancheId,
                stable,
                stable,
                lending.ownerOf(trancheId)
            );
        uint256 debt = lending.trancheDebt(trancheId);

        uint256 thresholdPer10k = lending.borrowable2LiqThresh(
            borrowablePer10k
        );

        bool _liquidatable = value * thresholdPer10k > 10_000 * debt;
        int256 netValueThreshold = (int256(value) *
            (10_000 - liquidationSharePer10k)) /
            10_000 -
            int256(debt);

        return (_liquidatable, netValueThreshold);
    }

    function liquidate(
        uint256 trancheId,
        int256 bid,
        address recipient,
        bytes calldata _data
    ) external {
        (bool _liquidatable, int256 netValueThresh) = getLiquidatability(
            trancheId
        );
        require(_liquidatable, "Tranche is not liquidatable");

        if (bid > netValueThresh) {
            IsolatedLending lending = isolatedLending();
            Stablecoin stable = stableCoin();

            if (bid > 0) {
                uint256 posBid = uint256(bid);
                stable.burn(msg.sender, posBid);

                stable.mint(lending.ownerOf(trancheId), posBid / 2);
                pendingFees += posBid / 2;
            } else {
                uint256 posBid = uint256(0 - bid);
                stable.mint(recipient, posBid);
            }

            lending.liquidateTo(trancheId, recipient, _data);
        }
    }

    function withdrawFees() external {
        stableCoin().mint(feeRecipient(), pendingFees);
        pendingFees = 0;
    }
}
