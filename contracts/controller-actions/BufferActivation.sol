// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Executor.sol";
import "../roles/DependsOnOracleRegistry.sol";
import "../roles/DependsOnStrategyRegistry.sol";
import "../roles/DependsOnStableLending2.sol";
import "../roles/DependsOnStableCoin.sol";
import "../DependencyController.sol";

contract BufferActivation is
    Executor,
    DependsOnStrategyRegistry,
    DependsOnStableLending2,
    DependsOnStableCoin,
    DependsOnOracleRegistry
{
    address[] tokens;

    constructor(address[] memory _tokens, address _roles) RoleAware(_roles) {
        tokens = _tokens;
        _rolesPlayed.push(MINTER_BURNER);
    }

    function execute() external override {
        StrategyRegistry registry = strategyRegistry();
        registry.enabledStrategy(address(this));

        OracleRegistry oracle = oracleRegistry();
        Stablecoin stable = stableCoin();
        StableLending2 lending = stableLending2();

        for (uint256 i; tokens.length > i; i++) {
            uint256 valPer1e18 = oracle.getAmountInPeg(
                tokens[i],
                1e18,
                address(stable)
            );

            (, , uint256 totalDebt) = lending.assetConfigs(tokens[i]);
            uint256 borrowAmount = (16 * totalDebt) / 100;
            uint256 depositAmount = (14 * borrowAmount * 1e18) /
                valPer1e18 /
                10;

            lending.mintDepositAndBorrow(
                tokens[i],
                address(this),
                depositAmount,
                borrowAmount,
                address(this)
            );
        }

        stable.burn(address(this), stable.balanceOf(address(this)));

        registry.disableStrategy(address(this));
        delete tokens;
        selfdestruct(payable(tx.origin));
    }

    function registerMintTranche(
        address minter,
        uint256,
        address,
        uint256,
        uint256
    ) external view {
        require(minter == address(this), "Calling from wrong minter");
    }
}
