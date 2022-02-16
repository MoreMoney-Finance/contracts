// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../roles/DependsOnStableCoin.sol";
import "../roles/DependsOnOracleRegistry.sol";
import "../roles/DependsOnTwapOracle.sol";
import "../roles/DependsOnFeeRecipient.sol";
import "../oracles/OracleAware.sol";

import "./AuxLPT.sol";

contract Rebalancer is RoleAware, DependsOnStableCoin, OracleAware {
    using SafeERC20 for IERC20;
    using SafeERC20 for Stablecoin;

    struct SmartLiqPool {
        AuxLPT stableLPT;
        AuxLPT counterLPT;
        IERC20 counterPartyToken;
        IUniswapV2Pair pair;
        uint256 debt;
        uint256 stableLTVPer10k;
        uint256 feeLPT;
        uint256 lastKRoot;
    }

    SmartLiqPool[] public liqPools;

    uint256 reserveWindowPer10k = (10_000 * 4) / 1000;
    uint256 reserveWindowConstant = 100 ether;

    constructor(address _roles) RoleAware(_roles) {
        _rolesPlayed.push(MINTER_BURNER);
        _rolesPlayed.push(SMART_LIQUIDITY);
    }

    function viewAllLiqPools() external view returns (SmartLiqPool[] memory) {
        return liqPools;
    }

    function _addLiqPool(
        address stableLPT,
        address counterLPT,
        address counterPartyToken,
        address pair,
        uint256 stableLTVPer10k
    ) internal returns (uint256) {
        liqPools.push(
            SmartLiqPool({
                stableLPT: AuxLPT(stableLPT),
                counterLPT: AuxLPT(counterLPT),
                counterPartyToken: IERC20(counterPartyToken),
                pair: IUniswapV2Pair(pair),
                debt: 0,
                stableLTVPer10k: stableLTVPer10k,
                feeLPT: 0,
                lastKRoot: sqrt(IUniswapV2Pair(pair).kLast())
            })
        );
        return liqPools.length - 1;
    }

    function setStableLTVPer10k(uint256 liqPoolId, uint256 ltv)
        external
        onlyOwnerExecDisabler
    {
        liqPools[liqPoolId].stableLTVPer10k = ltv;
    }

    function rebalance(uint256 liqPoolId) external returns (bool) {
        return _rebalance(liqPools[liqPoolId]);
    }

    function _rebalance(SmartLiqPool storage liqPool)
        internal
        virtual
        returns (bool)
    {
        uint256 stableBalance = stableCoin().balanceOf(
            address(liqPool.stableLPT)
        );

        address counterPartyToken = address(liqPool.counterPartyToken);
        uint256 debt = liqPool.debt;
        uint256 counterBalance = liqPool.counterPartyToken.balanceOf(
            address(liqPool.counterLPT)
        );
        uint256 stableReserves = viewStableReserves(
            address(liqPool.pair),
            counterPartyToken
        );
        uint256 counterReserves = viewCounterReserves(
            address(liqPool.pair),
            counterPartyToken
        );

        uint256 baseLptBalance = liqPool.pair.balanceOf(
            address(liqPool.counterLPT)
        );

        {
            uint256 kRoot = sqrt(liqPool.pair.kLast());
            if (kRoot > liqPool.lastKRoot) {
                liqPool.feeLPT =
                    (baseLptBalance * (kRoot - liqPool.lastKRoot)) /
                    kRoot;
                liqPool.lastKRoot = kRoot;
            }
        }

        if (
            _reservesWithinRange(
                counterPartyToken,
                stableReserves,
                counterReserves
            )
        ) {
            if (stableBalance > 0) {
                uint256 counterTarget = (counterReserves * stableBalance) /
                    counterReserves;
                uint256 counter2deposit = min(counterTarget, counterBalance);
                uint256 stable2deposit = (counter2deposit * stableBalance) /
                    counterTarget;

                stableCoin().safeTransferFrom(
                    address(liqPool.stableLPT),
                    address(liqPool.pair),
                    stable2deposit
                );
                IERC20(counterPartyToken).safeTransferFrom(
                    address(liqPool.counterLPT),
                    address(liqPool.pair),
                    counter2deposit
                );
                liqPool.pair.mint(address(liqPool.counterLPT));

                counterBalance -= counter2deposit;

                stableReserves = viewStableReserves(
                    address(liqPool.pair),
                    counterPartyToken
                );
                counterReserves = viewCounterReserves(
                    address(liqPool.pair),
                    counterPartyToken
                );
            }

            if ((10_000 * debt) / stableReserves > liqPool.stableLTVPer10k) {
                // deleverage -- remove LPT to extinguish debt
                uint256 targetDebt = ((stableReserves - debt) *
                    liqPool.stableLTVPer10k) /
                    (10_000 - liqPool.stableLTVPer10k);

                {
                    uint256 lpt2Withdraw = min(
                        baseLptBalance,
                        (baseLptBalance * (debt - targetDebt)) / stableReserves
                    );

                    _decreaseMinBalance(
                        address(liqPool.pair),
                        debt - targetDebt
                    );
                    IERC20(address(liqPool.pair)).safeTransferFrom(
                        address(liqPool.counterLPT),
                        address(liqPool.pair),
                        lpt2Withdraw
                    );
                }
                IUniswapV2Pair(liqPool.pair).burn(address(liqPool.counterLPT));
                uint256 stableReturned = IERC20(stableCoin()).balanceOf(
                    address(liqPool.counterLPT)
                );
                liqPool.debt -= debt - targetDebt;
                debt -= debt - targetDebt;

                uint256 newCounterBalance = IERC20(counterPartyToken).balanceOf(
                    address(liqPool.counterLPT)
                );

                stableCoin().burn(address(liqPool.counterLPT), stableReturned);
                if (stableReturned > debt - targetDebt) {
                    stableCoin().mint(
                        address(liqPool.stableLPT),
                        stableReturned - (debt - targetDebt)
                    );
                } else if (debt - targetDebt > stableReturned) {
                    uint256 shortfall = (debt - targetDebt) - stableReturned;
                    stableCoin().burn(address(liqPool.pair), shortfall);
                    uint256 counterRefund = min(
                        newCounterBalance,
                        (counterReserves * shortfall) / stableReserves
                    );
                    IERC20(counterPartyToken).safeTransferFrom(
                        address(liqPool.counterLPT),
                        address(liqPool.pair),
                        counterRefund
                    );
                    liqPool.pair.sync();
                    newCounterBalance -= counterRefund;
                }
                counterBalance = newCounterBalance;
            } else if (
                liqPool.stableLTVPer10k > (10_500 * debt) / stableReserves &&
                counterBalance > 0
            ) {
                // releverage -- deposit more liquidity to add debt
                uint256 targetDebtTotal = (liqPool.stableLTVPer10k *
                    (stableReserves - debt)) /
                    (10_000 - liqPool.stableLTVPer10k);
                uint256 targetDebtAdditional = targetDebtTotal - debt;
                uint256 targetCounterAdditional = (counterReserves *
                    targetDebtAdditional) / stableReserves;

                uint256 counter2add = min(
                    targetCounterAdditional,
                    counterBalance
                );
                uint256 debt2add = (counter2add * targetDebtAdditional) /
                    targetCounterAdditional;

                if (counter2add > 0) {
                    IERC20(counterPartyToken).safeTransferFrom(
                        address(liqPool.counterLPT),
                        address(liqPool.pair),
                        counter2add
                    );

                    stableCoin().mint(address(liqPool.pair), debt2add);
                    liqPool.debt += debt2add;
                    debt += debt2add;
                    _increaseMinBalance(address(liqPool.pair), debt2add);

                    liqPool.pair.mint(address(this));
                }
            }
            return true;
        } else {
            return false;
        }
    }

    /// Internal increase minimum balance of an account
    function _increaseMinBalance(address account, uint256 amount) internal {
        Stablecoin stable = stableCoin();
        stable.setMinBalance(account, stable.minBalance(account) + amount);
    }

    /// Internal decrease minimum balance of an account
    function _decreaseMinBalance(address account, uint256 amount) internal {
        Stablecoin stable = stableCoin();
        uint256 balance = stable.minBalance(account);
        stable.setMinBalance(account, balance >= amount ? balance - amount : 0);
    }

    /// Check whether reserves are in range of oracle
    function _reservesWithinRange(
        address counterPartyToken,
        uint256 stableReserves,
        uint256 counterReserves
    ) internal returns (bool) {
        uint256 counterValue = _getValue(
            counterPartyToken,
            counterReserves,
            address(stableCoin())
        );
        if (counterValue > stableReserves) {
            return
                (stableReserves * reserveWindowPer10k) /
                    10_000 +
                    reserveWindowConstant >=
                counterValue;
        } else {
            return
                (counterValue * reserveWindowPer10k) /
                    10_000 +
                    reserveWindowConstant >=
                stableReserves;
        }
    }

    /// View counter side reserves
    function viewCounterReserves(address uniPool, address counterPartyToken)
        public
        view
        returns (uint256)
    {
        address stable = address(stableCoin());
        (address token0, ) = sortTokens(stable, counterPartyToken);

        uint256 uniLPTBalance = IERC20(uniPool).balanceOf(address(this));
        uint256 uniTotalSupply = IERC20(uniPool).totalSupply();
        (uint256 reserves0, uint256 reserves1, ) = IUniswapV2Pair(uniPool)
            .getReserves();
        uint256 counterReserves = (uniLPTBalance *
            (token0 == counterPartyToken ? reserves0 : reserves1)) /
            uniTotalSupply;
        return counterReserves;
    }

    /// View total stable side reserves
    function viewStableReserves(address uniPool, address counterPartyToken)
        public
        view
        returns (uint256)
    {
        address stable = address(stableCoin());
        (address token0, ) = sortTokens(stable, counterPartyToken);

        uint256 uniLPTBalance = IERC20(uniPool).balanceOf(address(this));
        uint256 uniTotalSupply = ERC20(uniPool).totalSupply();
        (uint256 reserves0, uint256 reserves1, ) = IUniswapV2Pair(uniPool)
            .getReserves();
        uint256 stableReserves = (uniLPTBalance *
            (token0 == stable ? reserves0 : reserves1)) / uniTotalSupply;
        return stableReserves;
    }

    /// returns sorted token addresses, used to handle return values
    /// from pairs sorted in this order
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

    /// Minimum of two uints
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a >= b) {
            return b;
        } else {
            return a;
        }
    }

    /// Set reserve window
    function setReserveWindowPer10k(uint256 reserveWindow)
        external
        onlyOwnerExec
    {
        require(10_000 >= reserveWindow, "Window not in range");
        reserveWindowPer10k = reserveWindow;
        emit ParameterUpdated("Reserve window per 10k", reserveWindow);
    }

    function isAuthorizedSL(address caller) internal returns (bool) {
        if (roleCache[caller][SMART_LIQUIDITY]) {
            return true;
        } else {
            updateRoleCache(SMART_LIQUIDITY, caller);
            return roleCache[caller][SMART_LIQUIDITY];
        }
    }

    /// @notice Calculates the square root of x, rounding down.
    /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
    ///
    /// Caveats:
    /// - This function does not work with fixed-point numbers.
    ///
    /// @param x The uint256 number for which to calculate the square root.
    /// @return result The result as an uint256.
    function sqrt(uint256 x) internal pure returns (uint256 result) {
        if (x == 0) {
            return 0;
        }

        // Set the initial guess to the closest power of two that is higher than x.
        uint256 xAux = uint256(x);
        result = 1;
        if (xAux >= 0x100000000000000000000000000000000) {
            xAux >>= 128;
            result <<= 64;
        }
        if (xAux >= 0x10000000000000000) {
            xAux >>= 64;
            result <<= 32;
        }
        if (xAux >= 0x100000000) {
            xAux >>= 32;
            result <<= 16;
        }
        if (xAux >= 0x10000) {
            xAux >>= 16;
            result <<= 8;
        }
        if (xAux >= 0x100) {
            xAux >>= 8;
            result <<= 4;
        }
        if (xAux >= 0x10) {
            xAux >>= 4;
            result <<= 2;
        }
        if (xAux >= 0x8) {
            result <<= 1;
        }

        // The operations can never overflow because the result is max 2^127 when it enters this block.
        unchecked {
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1; // Seven iterations should be enough
            uint256 roundedDownResult = x / result;
            return result >= roundedDownResult ? roundedDownResult : result;
        }
    }
}
