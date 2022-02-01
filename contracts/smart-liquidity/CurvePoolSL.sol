// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../roles/DependsOnStableCoin.sol";
import "../roles/DependsOnCurvePool.sol";
import "../roles/DependsOnFeeRecipient.sol";
import "../roles/RoleAware.sol";
import "../../interfaces/ICurvePool.sol";

/// This is a prototype of curve pool smart liquidity
/// As a prototype it isn't hardened against pool manipulations
/// hence only callable by whitelist
contract CurvePoolSL is
    DependsOnStableCoin,
    DependsOnCurvePool,
    DependsOnFeeRecipient,
    RoleAware
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // amount of stablecoin deposited
    uint256 deposited;
    IERC20 counterparty = IERC20(0x5B5CFE992AdAC0C9D48E05854B2d91C73a003858);

    EnumerableSet.AddressSet internal whitelist;

    constructor(address _roles) RoleAware(_roles) {
        _rolesPlayed.push(MINTER_BURNER);
        Stablecoin(Roles(_roles).mainCharacters(STABLECOIN)).approve(
            Roles(_roles).mainCharacters(CURVE_POOL),
            type(uint256).max
        );
    }

    /// Main function of the contract
    /// checks ratio of reserves in pool and deposits or withdraws
    /// MONEY in order to restore balance
    function rebalance() external {
        require(isWhitelisted(msg.sender), "Not whitelisted");

        Stablecoin stable = stableCoin();
        address poolAddress = curvePool();
        ICurvePool pool = ICurvePool(poolAddress);

        uint256 stableBalance = stable.balanceOf(poolAddress);
        uint256 counterBalance = counterparty.balanceOf(poolAddress);

        uint256 lptSupply = IERC20(poolAddress).totalSupply();

        if (stableBalance * 100 > counterBalance * 101) {
            // we withdraw

            uint256 delta = stableBalance - counterBalance;
            uint256 lptBalance = IERC20(poolAddress).balanceOf(address(this));

            uint256 targetWithdrawAmount = min(
                lptBalance,
                (delta * lptSupply) / (stableBalance + counterBalance)
            );

            pool.remove_liquidity_one_coin(
                targetWithdrawAmount,
                0,
                (96 * targetWithdrawAmount * (stableBalance + counterBalance)) /
                    lptSupply /
                    100
            );
            uint256 actuallyWithdrawn = stable.balanceOf(address(this));

            if (deposited >= actuallyWithdrawn) {
                deposited -= actuallyWithdrawn;
            } else {
                stable.mint(feeRecipient(), actuallyWithdrawn - deposited);
                deposited = 0;
            }

            stable.burn(address(this), actuallyWithdrawn);
        } else if (counterBalance > stableBalance) {
            // we deposit

            uint256 delta = counterBalance - stableBalance;

            uint256 stableAvailable = stable.globalDebtCeiling() -
                stable.totalSupply();
            if (delta + deposited > (stableBalance * 2) / 3) {
                delta = (stableBalance * 2) / 3 - deposited;
            }
            if (delta > stableAvailable) {
                delta = (2 * stableAvailable) / 3;
            }

            stable.mint(address(this), delta);

            uint256 minReturn = (96 * (delta * lptSupply)) /
                (stableBalance + counterBalance) /
                100;

            pool.add_liquidity([delta, 0], minReturn);

            deposited += delta;
        }

        stable.setMinBalance(poolAddress, (deposited * 2) / 3);
    }

    /// Checks whether an account is whitelisted
    function isWhitelisted(address caller) public returns (bool) {
        return
            caller == owner() ||
            caller == executor() ||
            caller == disabler() ||
            whitelist.contains(caller);
    }

    /// Add an account to the whitelist
    function add2Whitelist(address caller) external onlyOwnerExec {
        whitelist.add(caller);
    }

    /// Remove account from whitelist
    function removeFromWhitelist(address caller) external onlyOwnerExec {
        whitelist.remove(caller);
    }

    /// Send fees gained by protocol owned position to fee recipient
    function withdrawFees() external {
        require(isWhitelisted(msg.sender), "Not whitelisted");

        Stablecoin stable = stableCoin();
        address poolAddress = curvePool();
        ICurvePool pool = ICurvePool(poolAddress);

        uint256 lptBalance = IERC20(poolAddress).balanceOf(address(this));
        uint256 lptSupply = IERC20(poolAddress).totalSupply();

        uint256 stableBalance = stable.balanceOf(poolAddress);
        uint256 counterBalance = counterparty.balanceOf(poolAddress);

        uint256 gains = (lptBalance * (stableBalance + counterBalance)) /
            lptSupply -
            deposited;

        uint256 withdrawAmount = (gains * lptSupply) /
            (stableBalance + counterBalance);
        pool.remove_liquidity_one_coin(withdrawAmount, 0, (gains * 9) / 10);

        uint256 actualGains = stable.balanceOf(address(this));
        stable.mint(feeRecipient(), actualGains);
        stable.burn(address(this), actualGains);
    }

    /// Rescue stranded funds
    function rescueFunds(
        address token,
        address recipient,
        uint256 amount
    ) external onlyOwnerExec {
        IERC20(token).safeTransfer(recipient, amount);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a >= b) {
            return b;
        } else {
            return a;
        }
    }
}
