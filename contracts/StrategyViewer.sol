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

        return augmentStratMetadata(lendingContract, stratMeta);
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

        return augmentStratMetadata(lendingContract, stratMeta);
    }


    /// Amalgamate lending metadata with strategy metadata
    function augmentStratMetadata(address lendingContract, IStrategy.StrategyMetadata[] memory stratMeta)
        public
        view
        returns (StableLending.ILStrategyMetadata[] memory)
    {
        StableLending.ILStrategyMetadata[] memory result = new StableLending.ILStrategyMetadata[](
            stratMeta.length
        );

        for (uint256 i; result.length > i; i++) {
            StableLending.ILStrategyMetadata memory meta = result[i];
            IStrategy.StrategyMetadata memory sMeta = stratMeta[i];
            StableLending.ILMetadata memory ilMeta = StableLending(lendingContract).viewILMetadata(sMeta.token);

            meta.debtCeiling = ilMeta.debtCeiling;
            meta.totalDebt = ilMeta.totalDebt;
            meta.mintingFee = ilMeta.mintingFee;

            meta.strategy = sMeta.strategy;
            meta.token = sMeta.token;
            meta.APF = sMeta.APF;
            meta.totalCollateral = sMeta.totalCollateral;
            meta.borrowablePer10k = sMeta.borrowablePer10k;
            meta.valuePer1e18 = sMeta.valuePer1e18;
            meta.strategyName = sMeta.strategyName;

            meta.tvl = sMeta.tvl;
            meta.harvestBalance2Tally = sMeta.harvestBalance2Tally;
            meta.yieldType = sMeta.yieldType;
            meta.stabilityFee = sMeta.stabilityFee;
            meta.underlyingStrategy = sMeta.underlyingStrategy;
        }

        return result;
    }
}
