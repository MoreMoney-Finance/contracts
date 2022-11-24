// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Executor.sol";
import "../roles/DependsOnStableLending.sol";
import "../roles/DependsOnStableLending2.sol";
import "../roles/DependsOnMetaLending.sol";
import "../roles/DependsOnOracleRegistry.sol";
import "../Strategy.sol";
import "../liquidation/StableLendingLiquidation.sol";
import "../liquidation/StableLending2Liquidation.sol";
import "../liquidation/MetaLendingLiquidation.sol";

contract TokenActivation is
    Executor,
    DependsOnStableLending,
    DependsOnStableLending2,
    DependsOnMetaLending,
    DependsOnOracleRegistry
{
    address[] public tokens;
    uint256[] public debtCeilings;
    uint256[] public feesPer10k;
    uint256[] public liquidationRewardPer10k;

    address public immutable liquidationContract;
    address public immutable liquidationContract2;

    constructor(
        address[] memory _tokens,
        uint256[] memory _debtCeilings,
        uint256[] memory _feesPer10k,
        uint256[] memory _liquidationRewardPer10k,
        address _liquidationContract,
        address _liquidationContract2,
        address _roles
    ) RoleAware(_roles) {
        uint256 len = _tokens.length;
        require(
            _debtCeilings.length == len &&
                _feesPer10k.length == len &&
                _liquidationRewardPer10k.length == len,
            "Lengths don't match"
        );
        tokens = _tokens;
        debtCeilings = _debtCeilings;
        feesPer10k = _feesPer10k;
        liquidationRewardPer10k = _liquidationRewardPer10k;
        liquidationContract = _liquidationContract;
        liquidationContract2 = _liquidationContract2;
    }

    function execute() external override {
        uint256 len = tokens.length;
        StableLending2 lending2 = stableLending2();
        MetaLending meta = metaLending();
        for (uint256 i; len > i; i++) {
            address token = tokens[i];
            lending2.setAssetDebtCeiling(token, debtCeilings[i]);
            lending2.setFeesPer10k(token, feesPer10k[i]);

            meta.setAssetDebtCeiling(token, debtCeilings[i]);
            meta.setFeesPer10k(token, feesPer10k[i]);

            MetaLendingLiquidation(liquidationContract2)
                .setLiquidationRewardPer10k(token, liquidationRewardPer10k[i]);
            // StableLending2Liquidation(liquidationContract2)
            //     .setLiquidationRewardPer10k(token, liquidationRewardPer10k[i]);

            // StableLending2Liquidation(liquidationContract2)
            //     .setLiquidationRewardPer10k(token, liquidationRewardPer10k[i]);
        }

        delete tokens;
        delete debtCeilings;
        delete feesPer10k;
        delete liquidationRewardPer10k;
        selfdestruct(payable(tx.origin));
    }
}
