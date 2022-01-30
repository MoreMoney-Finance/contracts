// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./StableLending.sol";
import "./Strategy.sol";

contract StrategyViewer {
    function viewMetadata(
        address lendingContract,
        address[] calldata tokens,
        address[] calldata strategies
    ) external view returns (StableLending.ILStrategyMetadata[] memory) {
        IStrategy.StrategyMetadata[]
            memory stratMeta = new IStrategy.StrategyMetadata[](tokens.length);

        for (uint256 i; tokens.length > i; i++) {
            stratMeta[i] = IStrategy(strategies[i]).viewStrategyMetadata(
                tokens[i]
            );
        }

        return StableLending(lendingContract).augmentStratMetadata(stratMeta);
    }

    function viewMetadataNoHarvestBalance(
        address lendingContract,
        address oracleRegistry,
        address stable,
        address[] calldata tokens,
        address[] calldata strategies
    ) external view returns (StableLending.ILStrategyMetadata[] memory) {
        IStrategy.StrategyMetadata[]
            memory stratMeta = new IStrategy.StrategyMetadata[](tokens.length);

        for (uint256 i; tokens.length > i; i++) {
            IOracle oracle = IOracle(
                OracleRegistry(oracleRegistry).tokenOracle(tokens[i], stable)
            );
            (uint256 value, uint256 borrowablePer10k) = oracle
                .viewPegAmountAndBorrowable(tokens[i], 1e18, stable);

            Strategy strat = Strategy(payable(strategies[i]));
            (, uint256 totalCollateralNow, , ) = strat.tokenMetadata(tokens[i]);
            stratMeta[i] = IStrategy.StrategyMetadata({
                strategy: strategies[i],
                token: tokens[i],
                APF: strat.viewAPF(tokens[i]),
                totalCollateral: totalCollateralNow,
                borrowablePer10k: borrowablePer10k,
                valuePer1e18: value,
                strategyName: strat.strategyName(),
                tvl: strat._viewTVL(tokens[i]),
                harvestBalance2Tally: 0,
                yieldType: strat.yieldType(),
                stabilityFee: strat.stabilityFeePer10k(tokens[i]),
                underlyingStrategy: strat.viewUnderlyingStrategy(tokens[i])
            });
        }

        return StableLending(lendingContract).augmentStratMetadata(stratMeta);
    }
}
