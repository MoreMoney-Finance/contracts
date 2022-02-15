// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Rebalancer.sol";
import "./SLFactory.sol";
import "../roles/DependsOnSLFactory.sol";

contract LaunchSL is Rebalancer, DependsOnSLFactory {

    uint256 defaultLTVPer10k = 30_000;
    constructor(address _roles) Rebalancer(_roles) {}

    function addLiqPool(IUniswapV2Pair pair, string calldata poolName, string calldata poolSymbol) external {
        address t0 = pair.token0();
        address t1 = pair.token1();
        address stable = address(stableCoin());
        require(stable == t0 || stable == t1, "Not a valid MONEY pair");
        address counterToken = t0 == stable
            ? t1
            : t0;
        (address stableLPT, address counterLPT) = slFactory().initPool(poolName, poolSymbol);
        _addLiqPool(stableLPT, counterLPT, counterToken, address(pair), defaultLTVPer10k);

        AuxLPT(stableLPT).setApproval(address(this), stable, type(uint256).max);
        AuxLPT(counterLPT).setApproval(address(this), address(pair), type(uint256).max);
        AuxLPT(counterLPT).setApproval(address(this), counterToken, type(uint256).max);
    }

    function addMoney(uint256 poolID, uint256 amount, uint256 minLPOut, address recipient) external {
        SmartLiqPool storage liqPool = liqPools[poolID];
        require(address(liqPool.pair) != address(0), "Not a valid pool ID");
        if (_rebalance(liqPool)) {
            Stablecoin stable = stableCoin();

            uint256 lpOut = amount * _stableSideValue(liqPool) / 1e18;
            require(lpOut >= minLPOut, "Insufficient LPT returned");
            
            stable.burn(msg.sender, amount);
            stable.mint(address(liqPool.stableLPT), amount);

            uint256 totalSupply = liqPool.stableLPT.totalSupply();

            if (100 * lpOut / totalSupply >= 3) {
                // it's worth rebalancing
                _rebalance(liqPool);
            }

            liqPool.stableLPT.mint(recipient, lpOut);
        }
    }

    function _stableSideValue(SmartLiqPool storage liqPool) internal returns (uint256) {
        // it's balance + reserves + stableside(fees) - debt
    }
}