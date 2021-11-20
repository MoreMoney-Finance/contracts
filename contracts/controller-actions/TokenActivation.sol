// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Executor.sol";
import "../roles/DependsOnIsolatedLending.sol";
import "../roles/DependsOnOracleRegistry.sol";
import "../Strategy.sol";
import "../IsolatedLendingLiquidation.sol";

contract TokenActivation is
    Executor,
    DependsOnIsolatedLending,
    DependsOnOracleRegistry
{
    address[] public tokens;
    uint256[] public debtCeilings;
    uint256[] public feesPer10k;
    uint256[] public liquidationRewardPer10k;

    address public immutable liquidationContract;

    constructor(
        address[] memory _tokens,
        uint256[] memory _debtCeilings,
        uint256[] memory _feesPer10k,
        uint256[] memory _liquidationRewardPer10k,
        address _liquidationContract,
        address _roles
    ) RoleAware(_roles) {
        tokens = _tokens;
        debtCeilings = _debtCeilings;
        feesPer10k = _feesPer10k;
        liquidationRewardPer10k = _liquidationRewardPer10k;
        liquidationContract = _liquidationContract;
    }

    function execute() external override {
        uint256 len = tokens.length;
        for (uint256 i; len > i; i++) {
            address token = tokens[i];
            isolatedLending().configureAsset(
                token,
                debtCeilings[i],
                feesPer10k[i]
            );

            IsolatedLendingLiquidation(liquidationContract)
                .setLiquidationRewardPer10k(token, liquidationRewardPer10k[i]);
        }

        delete tokens;
        delete debtCeilings;
        delete feesPer10k;
        delete liquidationRewardPer10k;
        selfdestruct(payable(tx.origin));
    }
}
