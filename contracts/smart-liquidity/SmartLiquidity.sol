// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../roles/RoleAware.sol";
import "./AuxLPT.sol";
import "../Stablecoin.sol";
import "../roles/DependsOnStableCoin.sol";
import "../oracles/OracleAware.sol";

contract SmartLiquidity is DependsOnStableCoin, RoleAware, OracleAware {
    using SafeERC20 for IERC20;
    
    address immutable factory;
    bytes32 immutable factoryInitHash;

    struct SmartLiqPool {
        address stableLPT;
        address counterLPT;
        address pair;
        uint256 stableBalance;
        uint256 debt;
        uint256 depositedStable;
        uint256 depositedCounter;
        uint256 stableLTVPer10k;
    }

    mapping(address => SmartLiqPool) public liqPools;

    uint256 reserveWindowPer10k = 10_000 * 4 / 1000;
    uint256 reserveWindowConstant = 100 ether; 
 
    constructor(address _factory, bytes32 _initHash, address _roles) RoleAware(_roles) {
        _rolesPlayed.push(MINTER_BURNER);
        _rolesPlayed.push(SMART_LIQUIDITY);
        factory = _factory;
        factoryInitHash = _initHash;
    }

    function initPool(address counterPartyToken, uint256 stableAmount, uint256 counterAmount) external {
        require(liqPools[counterPartyToken].pair == address(0), "Pool already initialized");
        Stablecoin stable = stableCoin();
        address pair = IUniswapV2Factory(factory).getPair(address(stable), counterPartyToken);
        if (pair == address(0)) {
            pair = IUniswapV2Factory(factory).createPair(address(stable), counterPartyToken);
        }
        // add oracle if it doesn't exist

        // deposit if amount ratios and reserves are within range
    }

    /// Add liquidity in our stablecoin
    function addStableLiquidity(address counterPartyToken, uint256 amount) external {
        Stablecoin stable = stableCoin();
        stable.burn(msg.sender, amount);

        SmartLiqPool storage liqPool = liqPools[counterPartyToken];
        liqPool.stableBalance += amount;


        AuxLPT stableLPT = AuxLPT(liqPool.stableLPT);
        uint256 lptAmount = amount * stableLPT.totalSupply() / _totalStablesideValue(liqPool, counterPartyToken);

        _rebalance(liqPool, counterPartyToken);

        require(25 ether > liqPool.stableBalance, "Not accepting liquidity");
        stableLPT.mint(msg.sender, lptAmount);
    }

    function addCounterLiquidity(address token, uint256 amount) external {
        SmartLiqPool storage liqPool = liqPools[token];
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        AuxLPT counterLPT = AuxLPT(liqPool.counterLPT);
        uint256 lptAmount = amount * counterLPT.totalSupply() / _totalCounterPartyValue(liqPool, token);

        _rebalance(liqPool, token);

        counterLPT.mint(msg.sender, lptAmount);
    }

    function rebalance(address counterPartyToken) external {
        _rebalance(liqPools[counterPartyToken], counterPartyToken);
    }

    function _rebalance(SmartLiqPool storage liqPool, address counterPartyToken) internal {
        uint256 debt = liqPool.debt;
        uint256 counterBalance = IERC20(counterPartyToken).balanceOf(address(this));
        uint256 stableReserves = viewStableReserves(liqPool.pair, counterPartyToken);
        uint256 counterReserves = viewCounterReserves(liqPool.pair, counterPartyToken);

        require(_reservesWithinRange(counterPartyToken, stableReserves, counterReserves), "Reserves not in oracle range");

        if (liqPool.stableBalance > 0) {
            // pay off any extant debt with our balance
            uint256 payOff = min(debt, liqPool.stableBalance);
            if (payOff > 0) {
                liqPool.stableBalance -= payOff;
                debt -= payOff;
                liqPool.debt -= payOff;
                _decreaseMinBalance(liqPool.pair, payOff);
            }

            // if there's remaining balance and we have counterparty tokens, deposit more liquidity
            if (liqPool.stableBalance > 0 && counterBalance > 0) {
                uint256 counterTarget = counterReserves * liqPool.stableBalance / counterReserves;
                uint256 counter2deposit = min(counterTarget, counterBalance);
                uint256 stable2deposit = counter2deposit * liqPool.stableBalance / counterTarget;

                stableCoin().mint(liqPool.pair, stable2deposit);
                IERC20(counterPartyToken).safeTransfer(liqPool.pair, counter2deposit);
                IUniswapV2Pair(liqPool.pair).mint(address(this));

                counterBalance -= counter2deposit;
                liqPool.stableBalance -= stable2deposit;
                stableReserves = viewStableReserves(liqPool.pair, counterPartyToken);
                counterReserves = viewCounterReserves(liqPool.pair, counterPartyToken);
            }
        }

        if (10_000 * debt / stableReserves > liqPool.stableLTVPer10k) {
            // deleverage -- remove LPT to extinguish debt
            uint256 targetDebt = (stableReserves - debt) * liqPool.stableLTVPer10k / (10_000 - liqPool.stableLTVPer10k);
            uint256 lptBalance = IERC20(liqPool.pair).balanceOf(address(this));
            uint256 lpt2Withdraw = lptBalance * (debt - targetDebt) / stableReserves;

            IERC20(liqPool.pair).safeTransfer(liqPool.pair, lpt2Withdraw);
            IUniswapV2Pair(liqPool.pair).burn(address(this));
            uint256 debt2burn = IERC20(stableCoin()).balanceOf(address(this));
            stableCoin().burn(address(this), debt2burn);
            liqPool.debt -= debt2burn;
            debt -= debt2burn;

            uint256 newCounterBalance = IERC20(counterPartyToken).balanceOf(address(this));
            liqPool.depositedCounter -= newCounterBalance - counterBalance;
            counterBalance = newCounterBalance;

        } else if (liqPool.stableLTVPer10k > 10_500 * debt / stableReserves && counterBalance > 0) {
            // releverage -- deposit more liquidity to add debt
            uint256 targetDebtTotal = liqPool.stableLTVPer10k * (stableReserves - debt) / (10_000 - liqPool.stableLTVPer10k);
            uint256 targetDebtAdditional = targetDebtTotal - debt;
            uint256 targetCounterAdditional = counterReserves * targetDebtAdditional / stableReserves;

            uint256 counter2add = min(targetCounterAdditional, counterBalance);
            uint256 debt2add = counter2add * targetDebtAdditional / targetCounterAdditional;

            if (counter2add > 0) {
                IERC20(counterPartyToken).safeTransfer(liqPool.pair, counter2add);
                liqPool.depositedCounter += counter2add;

                stableCoin().mint(liqPool.pair, debt2add);
                liqPool.debt += debt2add;
                debt += debt2add;
                _increaseMinBalance(liqPool.pair, debt2add);

                IUniswapV2Pair(liqPool.pair).mint(address(this));
            }
        }
    }

    function _totalCounterPartyValue(SmartLiqPool storage liqPool, address counterPartyToken) internal view returns (uint256) {
        uint256 stableReserves = viewStableReserves(liqPool.pair, counterPartyToken);
        uint256 counterPartyReserves = viewCounterReserves(liqPool.pair, counterPartyToken);
        uint256 counterBalance = IERC20(counterPartyToken).balanceOf(address(this));

        if (stableReserves > liqPool.debt + liqPool.depositedStable) {
            return counterBalance + liqPool.depositedCounter + counterPartyReserves * (stableReserves - liqPool.debt - liqPool.depositedStable) / 2 / stableReserves;
        } else {
            return counterBalance + (counterPartyReserves - liqPool.depositedCounter) / 2;
        }
    }

    function _totalStablesideValue(SmartLiqPool storage liqPool, address counterPartyToken) internal view returns (uint256) {
        uint256 stableReserves = viewStableReserves(liqPool.pair, counterPartyToken);
        if (stableReserves > liqPool.debt + liqPool.depositedStable) {
            return liqPool.stableBalance + liqPool.depositedStable + (stableReserves - liqPool.debt - liqPool.depositedStable) / 2;
        } else {
            uint256 counterPartyReserves = viewCounterReserves(liqPool.pair, counterPartyToken);
            return liqPool.stableBalance + stableReserves - liqPool.debt + stableReserves * (counterPartyReserves - liqPool.depositedCounter) / counterPartyReserves;
        }
    }

    function viewStableReserves(address uniPool, address counterPartyToken) public view returns (uint256) {
        address stable = address(stableCoin());
        (address token0,) = sortTokens(stable, counterPartyToken);
        
        uint256 uniLPTBalance = IERC20(uniPool).balanceOf(address(this));
        uint256 uniTotalSupply =  ERC20(uniPool).totalSupply();
        (uint256 reserves0, uint256 reserves1, ) = IUniswapV2Pair(uniPool).getReserves();
        uint256 stableReserves = uniLPTBalance * (token0 == stable ? reserves0 : reserves1) / uniTotalSupply;
        return stableReserves;
    }

    function viewCounterReserves(address uniPool, address counterPartyToken) public view returns (uint256) {
        address stable = address(stableCoin());
        (address token0,) = sortTokens(stable, counterPartyToken);

        uint256 uniLPTBalance = IERC20(uniPool).balanceOf(address(this));
        uint256 uniTotalSupply =  IERC20(uniPool).totalSupply();
                (uint256 reserves0, uint256 reserves1, ) = IUniswapV2Pair(uniPool).getReserves();
        uint256 counterReserves = uniLPTBalance * (token0 == counterPartyToken ? reserves0 : reserves1) / uniTotalSupply;
        return counterReserves;
    }

    function _reservesWithinRange(address counterPartyToken, uint256 stableReserves, uint256 counterReserves) internal returns (bool) {
        uint256 counterValue = _getValue(counterPartyToken, counterReserves, address(stableCoin()));
        if (counterValue > stableReserves) {
            return stableReserves * reserveWindowPer10k / 10_000 + reserveWindowConstant >= counterValue;
        } else {
            return counterValue * reserveWindowPer10k / 10_000 + reserveWindowConstant >= stableReserves;
        }
    }

    function _increaseMinBalance(address account, uint256 amount) internal {
        Stablecoin stable = stableCoin();
        stable.setMinBalance(account, stable.minBalance(account) + amount);
    }

    function _decreaseMinBalance(address account, uint256 amount) internal {
        Stablecoin stable = stableCoin();
        uint256 balance = stable.minBalance(account);
        stable.setMinBalance(account, balance >= amount ? balance - amount : 0);
    }

    /// calculates the CREATE2 address for a pair without making any external calls
    function pairForAMM(address tokenA, address tokenB)
        internal
        view
        returns (address pair)
    {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            factoryInitHash
                        )
                    )
                )
            )
        );
    }

    /// returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "Identical address!");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "Zero address!");
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a >= b) {
            return b;
        } else {
            return a;
        }
    }
}