// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./OracleAware.sol";
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
    uint256 public generalLiqThresh = 1100;
    int256 public liquidationSharePermil = 30;
    uint256 public pendingFees;

    constructor(address _roles) RoleAware(_roles) {}

    function liquidatable(uint256 trancheId) public view returns (bool) {
        address stable = address(stableCoin());
        IsolatedLending lending = isolatedLending();
        (uint256 yield, uint256 value, uint256 colRatio) = lending
            .viewYieldValueColRatio(trancheId, stable, stable);
        uint256 debt = lending.trancheDebt(trancheId);

        uint256 thresholdPermil = min(
            generalLiqThresh,
            1000 + (colRatio - 1000) / 2
        );
        return debt * thresholdPermil > (value + yield) * 1000;
    }

    function getLiquidatability(uint256 trancheId)
        public
        returns (bool, int256)
    {
        IsolatedLending lending = isolatedLending();
        address stable = address(stableCoin());
        (, uint256 value, uint256 colRatio) = lending.collectYieldValueColRatio(
            trancheId,
            stable,
            stable,
            lending.ownerOf(trancheId)
        );
        uint256 debt = lending.trancheDebt(trancheId);

        uint256 thresholdPermil = min(
            generalLiqThresh,
            1000 + (colRatio - 1000) / 2
        );
        bool _liquidatable = debt * thresholdPermil > value * 1000;
        int256 netValueThreshold = (int256(value) *
            (1000 - liquidationSharePermil)) /
            1000 -
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

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return b;
        } else {
            return a;
        }
    }

    function withdrawFees() external {
        stableCoin().mint(feeRecipient(), pendingFees);
        pendingFees = 0;
    }
}
