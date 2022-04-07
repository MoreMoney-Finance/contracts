// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./LyLptHolder.sol";
import "../../interfaces/IsAvax.sol";
import "../../interfaces/IWETH.sol";
import "../roles/RoleAware.sol";
import "../smart-liquidity/AuxLPT.sol";

/// Matches up sAvax and Avax deposits to be put in the liquidity pool
contract LyRebalancer is RoleAware, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for IUniswapV2Pair;
    using SafeERC20 for IsAvax;
    using SafeERC20 for IWETH;

    IUniswapV2Pair public constant pair =
        IUniswapV2Pair(0x4b946c91C2B1a7d7C40FB3C130CdfBaf8389094d);
    IsAvax public constant sAvax =
        IsAvax(0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE);
    IWETH public constant wAvax =
        IWETH(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);

    address public immutable msAvax;
    address public immutable mAvax;
    LyLptHolder public lyLptHolder;
    uint256 public windowPer10k = 35;
    uint256 public minBalancePer10k = 3000;

    constructor(
        address msAVAX,
        address mAVAX,
        address _lyLptHolder,
        address _roles
    ) RoleAware(_roles) {
        msAvax = msAVAX;
        mAvax = mAVAX;
        lyLptHolder = LyLptHolder(_lyLptHolder);

        _rolesPlayed.push(LIQUID_YIELD);
        _charactersPlayed.push(LIQUID_YIELD_REBALANCER);
    }

    receive() external payable {}

    fallback() external payable {}

    /// Put any matching balances into the liquidity pool, if it is close enough to peg
    function depositBalances() public nonReentrant {
        (bool close2Peg, uint256 sAvaxRes, uint256 wAvaxRes) = _arbitrage();

        if (close2Peg) {
            // If arbitrage is completed we are in peg and can deposit
            // close enough to peg (so we don't suffer too much IL)
            uint256 sAvaxBalance = sAvax.balanceOf(msAvax);
            uint256 wAvaxBalance = wAvax.balanceOf(mAvax);

            if (sAvaxBalance > 0 && wAvaxBalance > 0) {
                // move whatever we can match up into the liquidity pool
                uint256 sAvaxDeposit = min(
                    sAvaxBalance,
                    (wAvaxBalance * sAvaxRes) / wAvaxRes
                );
                uint256 wAvaxDeposit = min(
                    wAvaxBalance,
                    (sAvaxBalance * wAvaxRes) / sAvaxRes
                );

                AuxLPT(msAvax).transferFunds(
                    sAvax,
                    address(pair),
                    sAvaxDeposit
                );
                AuxLPT(mAvax).transferFunds(wAvax, address(pair), wAvaxDeposit);

                // mint LPT and deposit to staking
                pair.mint(address(lyLptHolder));
                lyLptHolder.deposit();
            }
        }
    }

    /// Deposit sAVAX and receive msAVAX
    function mintMsAvax(uint256 amount) external {
        sAvax.safeTransferFrom(msg.sender, msAvax, amount);
        depositBalances();
        AuxLPT(msAvax).mint(msg.sender, amount);
    }

    /// Deposit WAVAX and mint mAVAX
    function mintMAvax(uint256 amount) external {
        wAvax.safeTransferFrom(msg.sender, mAvax, amount);
        depositBalances();
        AuxLPT(mAvax).mint(msg.sender, amount);
    }

    /// Deposit AVAX and mint mAVAX
    function mintMAvax() external payable {
        wAvax.deposit{value: msg.value}();
        wAvax.safeTransfer(mAvax, msg.value);
        depositBalances();
        AuxLPT(mAvax).mint(msg.sender, msg.value);
    }

    /// withdraw sAVAX
    function burnMsAvax(uint256 amount, address recipient) external {
        AuxLPT(msAvax).burn(msg.sender, amount);
        uint256 extantBalance = sAvax.balanceOf(msAvax);
        if (amount >= extantBalance) {
            _withdrawSAvaxFromLp(amount - extantBalance);
        }

        AuxLPT(msAvax).transferFunds(sAvax, recipient, amount);
        depositBalances();
    }

    /// Withdraw WAVAX
    function burnMAvax2wAvax(uint256 amount, address recipient) external {
        AuxLPT(mAvax).burn(msg.sender, amount);
        uint256 extantBalance = wAvax.balanceOf(mAvax);
        if (amount >= extantBalance) {
            _withdrawWAvaxFromLp(amount - extantBalance);
        }

        AuxLPT(mAvax).transferFunds(wAvax, recipient, amount);
        depositBalances();
    }

    /// Withdraw AVAX
    function burnMAvax2Avax(uint256 amount, address recipient) external {
        AuxLPT(mAvax).burn(msg.sender, amount);
        uint256 extantBalance = wAvax.balanceOf(mAvax);
        if (amount >= extantBalance) {
            _withdrawWAvaxFromLp(amount - extantBalance);
        }

        AuxLPT(mAvax).transferFunds(wAvax, address(this), amount);
        wAvax.withdraw(amount);
        payable(recipient).transfer(amount);
        depositBalances();
    }

    /// Exploit imbalances in liquidity pool
    function _arbitrage()
        internal
        returns (
            bool,
            uint256,
            uint256
        )
    {
        (uint256 sAvaxRes, uint256 wAvaxRes, ) = pair.getReserves();
        uint256 sAvaxResInAVAX = sAvax.getPooledAvaxByShares(sAvaxRes);
        bool close2Peg = false;

        // k = wAvaxRes * sAvaxRes
        // k = wAvaxRes * (sAvaxResInAVAX * CONVERSION_FACTOR)
        // if the pool is in peg (sAvaxResInAVAX == wAvaxRes):
        // k = wAvaxRes^2 * CONVERSION_FACTOR

        uint256 wAvaxResTarget = sqrt(sAvaxResInAVAX * wAvaxRes);

        uint256 wAvaxBalance = wAvax.balanceOf(mAvax);
        uint256 sAvaxBalance = sAvax.balanceOf(msAvax);

        if (
            (wAvaxResTarget * (10_000 - 2 * windowPer10k)) / 10_000 > wAvaxRes
        ) {
            // put in WAVAX, take out sAVAX
            uint256 inAmountTarget = ((wAvaxResTarget * (10_000 - windowPer10k)) /
                1000 -
                wAvaxRes);
            uint256 inAmount = min(wAvaxBalance, inAmountTarget);
            uint256 outAmount = getAmountOut(inAmount, wAvaxRes, sAvaxRes);

            if (
                sAvax.getPooledAvaxByShares(outAmount) >= inAmount &&
                lyLptHolder.viewStakedBalance() + wAvaxBalance - inAmount >=
                (AuxLPT(mAvax).totalSupply() * minBalancePer10k) / 10_000
            ) {
                AuxLPT(mAvax).transferFunds(wAvax, address(pair), inAmount);
                pair.swap(outAmount, 0, msAvax, "");

                close2Peg = inAmount >= inAmountTarget * 99 / 100;
                sAvaxRes -= outAmount;
                wAvaxRes += inAmount;
            }
        } else if (
            (wAvaxRes * (10_000 - 2 * windowPer10k)) / 10_000 > wAvaxResTarget
        ) {
            // put in sAVAX, take out WAVAX
            uint256 outAmount = (wAvaxRes -
                (wAvaxResTarget * (10_000 + windowPer10k)) /
                1000);
            uint256 inAmount = getAmountIn(outAmount, sAvaxRes, wAvaxRes);

            if (
                sAvaxBalance >= inAmount &&
                outAmount >= sAvax.getPooledAvaxByShares(inAmount) &&
                lyLptHolder.viewStakedBalance() + sAvaxBalance - inAmount >=
                (AuxLPT(msAvax).totalSupply() * minBalancePer10k) / 10_000
            ) {
                AuxLPT(msAvax).transferFunds(sAvax, address(pair), inAmount);
                pair.swap(0, outAmount, mAvax, "");

                close2Peg = true;
                sAvaxRes += inAmount;
                wAvaxRes -= outAmount;
            }
        } else {
            // we must be at peg, rougly
            close2Peg = true;
        }

        return (close2Peg, sAvaxRes, wAvaxRes);
    }

    /// Internall pull all funds
    function _pullAllFunds() internal {
        // first pull out all our liquidity
        lyLptHolder.withdrawAll(address(pair));

        if (pair.balanceOf(address(pair)) > 0) {
            pair.burn(address(this));

            sAvax.safeTransfer(msAvax, sAvax.balanceOf(address(this)));
            wAvax.safeTransfer(mAvax, wAvax.balanceOf(address(this)));
        }
    }

    function arbitrage() external {
        _pullAllFunds();
        depositBalances();
    }

    /// Pull funds from liquidity pool to balance by admin
    function pullAllFunds() external onlyOwnerExecDisabler {
        _pullAllFunds();
    }

    /// set minbalance parameter -- needs to be adjusted over time, as
    /// value of LPT increases (right now it's rougly 1:2)
    function setMinBalancePer10k(uint256 minbalance) external onlyOwnerExec {
        minBalancePer10k = minbalance;
    }

    /// Internally pull WAVAX out of liquidity pool
    function _withdrawWAvaxFromLp(uint256 amount) internal {
        uint256 wAvaxRes = wAvax.balanceOf(address(pair));
        uint256 supply = pair.totalSupply();

        uint256 stakedBalance = lyLptHolder.viewStakedBalance();
        uint256 burnAmount = min(
            stakedBalance,
            1e14 + (supply * amount) / wAvaxRes
        );

        _burnLpt(burnAmount);
    }

    //// Internally pull sAVAX out of liquidity pool
    function _withdrawSAvaxFromLp(uint256 amount) internal {
        uint256 sAvaxRes = sAvax.balanceOf(address(pair));
        uint256 supply = pair.totalSupply();

        uint256 stakedBalance = lyLptHolder.viewStakedBalance();
        uint256 burnAmount = min(
            stakedBalance,
            1e14 + (supply * amount) / sAvaxRes
        );

        _burnLpt(burnAmount);
    }

    /// Move LPT from masterchef back to pool and withdraw funds
    function _burnLpt(uint256 burnAmount) internal {
        lyLptHolder.withdraw(burnAmount, address(pair));
        pair.burn(address(this));

        wAvax.safeTransfer(mAvax, wAvax.balanceOf(address(this)));
        sAvax.safeTransfer(msAvax, sAvax.balanceOf(address(this)));
    }

    /// Rescue stranded funds
    function rescueFunds(
        address token,
        address recipient,
        uint256 amount
    ) external onlyOwnerExec {
        IERC20(token).safeTransfer(recipient, amount);
    }

    /// Set acceptable deviation from peg
    function setWindowPer10k(uint256 window) external onlyOwnerExec {
        require(10_000 >= window, "Window out of bounds");
        windowPer10k = window;
    }

    /// given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /// given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a >= b) {
            return b;
        } else {
            return a;
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
