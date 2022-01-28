// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./StableLending.sol";

contract StrategyViewer {
    function viewMetadata(
        address lendingContract,
        address[] calldata tokens,
        address[] calldata strategies
    ) external view returns (StableLending.ILStrategyMetadata[] memory) {
        IStrategy.StrategyMetadata[] memory stratMeta = new IStrategy.StrategyMetadata[](tokens.length);

        for (uint i; tokens.length > i; i++) {
            stratMeta[i] = IStrategy(strategies[i]).viewStrategyMetadata(tokens[i]);
        }

        return StableLending(lendingContract).augmentStratMetadata(stratMeta);
    }
}
