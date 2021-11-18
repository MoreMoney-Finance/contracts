// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./oracles/OracleAware.sol";
import "./roles/RoleAware.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IsolatedLending.sol";
import "./roles/DependsOnStableCoin.sol";
import "./roles/DependsOnIsolatedLending.sol";
import "./roles/DependsOnFeeRecipient.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// Liquidation contract for IsolatedLending
contract IsolatedLendingLiquidation is
    RoleAware,
    DependsOnStableCoin,
    DependsOnIsolatedLending,
    DependsOnFeeRecipient,
    ReentrancyGuard
{
    mapping(address => int256) public liquidationSharePer10k;
    int256 public defaultLiquidationSharePer10k;
    uint256 public pendingFees;

    constructor(address _roles) RoleAware(_roles) {
        _rolesPlayed.push(LIQUIDATOR);
        _rolesPlayed.push(FUND_TRANSFERER);
    }

    /// Retrieve liquidatability, disbursing yield and updating oracles
    function getLiquidatability(uint256 trancheId)
        internal
        returns (bool, int256)
    {
        IsolatedLending lending = isolatedLending();
        address stable = address(stableCoin());
        uint256 value = lending.collectYield(
            trancheId,
            stable,
            lending.ownerOf(trancheId)
        );
        uint256 debt = lending.trancheDebt(trancheId);

        bool _liquidatable = !lending.isViable(trancheId);

        int256 liqShare = liquidationSharePer10k[
            lending.trancheToken(trancheId)
        ];
        if (liqShare == 0) {
            liqShare = defaultLiquidationSharePer10k;
        }

        int256 netValueThreshold = (int256(value) * (10_000 - liqShare)) /
            10_000 -
            int256(debt);

        return (_liquidatable, netValueThreshold);
    }

    /// Run liquidation of a tranche
    function liquidate(
        uint256 trancheId,
        int256 bid,
        address recipient,
        bytes calldata _data
    ) external nonReentrant {
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

    /// Transfer fees to feeRecipient
    function withdrawFees() external {
        stableCoin().mint(feeRecipient(), pendingFees);
        pendingFees = 0;
    }

    /// Set liquidation share per asset
    function setLiquidationSharePer10k(address token, uint256 liqSharePer10k)
        external
        onlyOwnerExecDisabler
    {
        liquidationSharePer10k[token] = int256(liqSharePer10k);
    }

    /// Set liquidation share in default
    function setDefaultLiquidationSharePer10k(uint256 liqSharePer10k)
        external
        onlyOwnerExec
    {
        defaultLiquidationSharePer10k = int256(liqSharePer10k);
    }
}
