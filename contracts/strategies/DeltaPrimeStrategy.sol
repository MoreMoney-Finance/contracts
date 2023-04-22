// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Strategy2.sol";
import "../../interfaces/IYakStrategy.sol";
import "../../interfaces/IDeltaPrimePool.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../roles/DependsOnFeeRecipient.sol";

/// Compounding strategy using DeltaPrime
contract DeltaPrimeStrategy is Strategy2, DependsOnFeeRecipient {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public deltaPrimePool;
    mapping(address => address) public deltaStrategy;
    mapping(uint256 => uint256) public depositedMultiple;
    mapping(address => uint256) public feeMultiple;
    mapping(address => uint256) public feeBase;
    mapping(address => uint256) public startingTokensPerShare;
    uint256 public withdrawnFees;
    uint256 public totalShares;

    uint256 feePer10k = 1000;

    constructor(
        address _roles
    ) Strategy2("DeltaPrime compounding") TrancheIDAware(_roles) {}

    /// Withdraw from user account and deposit into DeltaPrime strategy
    function collectCollateral(
        address source,
        address token,
        uint256 collateralAmount
    ) internal virtual override returns (uint256) {
        IERC20(token).safeTransferFrom(source, address(this), collateralAmount);

        address dS = deltaStrategy[token];
        IERC20(token).safeIncreaseAllowance(dS, collateralAmount);
        IDeltaPrimePool(dS).deposit(collateralAmount);

        uint256 balanceOf = IDeltaPrimePool(dS).balanceOf(address(this));
        uint256 shares = (collateralAmount * totalShares) / balanceOf;
        totalShares += shares;

        return collateralAmount;
        // return
        //     getDepositTokensForShares(
        //         IERC20(dS).balanceOf(address(this)) - balanceBefore
        //     );
    }

    /// Withdraw from yy strategy and return to user
    function returnCollateral(
        address recipient,
        address token,
        uint256 targetAmount
    ) internal virtual override returns (uint256) {
        require(recipient != address(0), "Don't send to zero address");

        address dS = deltaStrategy[token];
        uint256 receiptAmount = getSharesForDepositTokens(targetAmount);

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IDeltaPrimePool(dS).withdraw(targetAmount);
        uint256 balanceDelta = IERC20(token).balanceOf(address(this)) -
            balanceBefore;

        totalShares -= receiptAmount;

        IERC20(token).safeTransfer(recipient, balanceDelta);

        return balanceDelta;
    }

    /// View collateral owned by tranche, taking into account compounding and fee
    function viewTargetCollateralAmount(
        uint256 trancheId
    ) public view override returns (uint256) {
        CollateralAccount storage account = _accounts[trancheId];
        uint256 originalAmount = account.collateral;

        uint256 feeFactor = 10_000 - feePer10k;

        uint256 current = currentWithYield(
            account.trancheToken,
            account.collateral,
            depositedMultiple[trancheId]
        );

        if (current > originalAmount) {
            return
                originalAmount +
                (current * feeFactor) /
                10_000 -
                (originalAmount * feeFactor) /
                10_000;
        } else {
            return current;
        }
    }

    function getDepositTokensForShares(
        uint256 shares
    ) public view returns (uint256) {
        if (totalShares == 0) {
            return shares;
        }
        return
            (shares *
                IDeltaPrimePool(deltaPrimePool).balanceOf(address(this))) /
            totalShares;
    }

    function getSharesForDepositTokens(
        uint256 depositTokens
    ) public view returns (uint256) {
        if (totalShares == 0) {
            return depositTokens;
        }
        return
            (depositTokens * totalShares) /
            IDeltaPrimePool(deltaPrimePool).balanceOf(address(this));
    }

    /// Set the yy strategy for a token
    function setDeltaStrategy(
        address token,
        address strategy
    ) external virtual onlyOwnerExec {
        changeUnderlyingStrat(token, strategy);
    }

    /// Check whether a token is approved and encode params
    function checkApprovedAndEncode(
        address token,
        address strategy
    ) public view returns (bool, bytes memory) {
        return (approvedToken(token), abi.encode(strategy));
    }

    /// Internal, initialize a token
    function _approveToken(
        address token,
        bytes calldata data
    ) internal virtual override {
        address newStrat = abi.decode(data, (address));
        require(
            IDeltaPrimePool(newStrat).tokenAddress() == token,
            "Provided yak strategy does not take token as deposit"
        );
        changeUnderlyingStrat(token, newStrat);

        super._approveToken(token, data);
    }

    /// Internal, applies compounding to the tranche balance, minus fees
    function _collectYield(
        uint256 trancheId,
        address,
        address
    ) internal override returns (uint256) {
        CollateralAccount storage account = _accounts[trancheId];
        if (account.collateral > 0) {
            address token = account.trancheToken;
            TokenMetadata storage tokenMeta = tokenMetadata[token];

            uint256 newAmount = viewTargetCollateralAmount(trancheId);
            uint256 oldAmount = account.collateral;

            uint256 current = currentWithYield(
                token,
                oldAmount,
                depositedMultiple[trancheId]
            );

            uint256 fees = current > newAmount ? current - newAmount : 0;
            feeBase[token] =
                fees +
                currentWithYield(token, feeBase[token], feeMultiple[token]);

            uint256 m = currentMultiple(token);
            feeMultiple[token] = m;
            depositedMultiple[trancheId] = m;

            // prevent underflow on withdrawals
            tokenMeta.totalCollateralNow =
                tokenMeta.totalCollateralNow +
                newAmount -
                oldAmount;

            account.collateral = newAmount;
        }

        return 0;
    }

    /// Set deposited shares -- the counterweight to _collectYield
    function _handleBalanceUpdate(
        uint256 trancheId,
        address token,
        uint256
    ) internal override {
        depositedMultiple[trancheId] = currentMultiple(token);
    }

    /// TVL per token
    function _viewTVL(address token) public view override returns (uint256) {
        address strat = deltaStrategy[token];
        return
            getDepositTokensForShares(IERC20(strat).balanceOf(address(this)));
    }

    /// compounding
    function yieldType() public pure override returns (IStrategy.YieldType) {
        return IStrategy.YieldType.COMPOUNDING;
    }

    /// All fees including currently pending and already withdrawn
    function viewAllFeesEver()
        external
        view
        override
        returns (uint256 balance)
    {
        for (uint256 i; _allTokensEver.length() > i; i++) {
            address token = _allTokensEver.at(i);
            balance += _viewValue(
                token,
                currentWithYield(token, feeBase[token], feeMultiple[token]),
                yieldCurrency()
            );
        }

        balance += withdrawnFees;
    }

    /// Withdraw fees for one token
    function withdrawFees(address token) public {
        uint256 amount = currentWithYield(
            token,
            feeBase[token],
            feeMultiple[token]
        );

        returnCollateral(feeRecipient(), token, amount);
        withdrawnFees += _getValue(token, amount, yieldCurrency());
        feeBase[token] = 0;
        feeMultiple[token] = currentMultiple(token);
    }

    /// Withdraw all acrrued fees
    function withdrawAllFees() external {
        for (uint256 i; _allTokensEver.length() > i; i++) {
            address token = _allTokensEver.at(i);
            withdrawFees(token);
        }
    }

    /// Call reinvest
    function harvestPartially(address token) external override nonReentrant {}

    /// View amount of yield that yak strategy could reinvest
    function viewSourceHarvestable(
        address token
    ) public view override returns (uint256) {
        return 0;
    }

    // View the underlying yield strategy (if any)
    function viewUnderlyingStrategy(
        address token
    ) public view virtual override returns (address) {
        return deltaStrategy[token];
    }

    function depositedShares(uint256 trancheId) public view returns (uint256) {}

    function currentMultiple(address token) public view returns (uint256) {
        return
            (1e18 * getDepositTokensForShares(1e18)) /
            startingTokensPerShare[token];
    }

    function currentWithYield(
        address token,
        uint256 collateral,
        uint256 multipleWhenDeposited
    ) internal view returns (uint256) {
        return (currentMultiple(token) * collateral) / multipleWhenDeposited;
    }

    function changeUnderlyingStrat(address token, address newStrat) internal {
        address current = deltaStrategy[token];
        if (current != address(0)) {
            uint256 balanceBefore = IERC20(token).balanceOf(address(this));
            IDeltaPrimePool(current).withdraw(
                IERC20(current).balanceOf(address(this))
            );
            uint256 balanceDelta = IERC20(token).balanceOf(address(this)) -
                balanceBefore;

            IDeltaPrimePool(newStrat).deposit(balanceDelta);

            startingTokensPerShare[token] =
                (getDepositTokensForShares(1e18) *
                    startingTokensPerShare[token]) /
                getDepositTokensForShares(1e18);
        } else {
            deltaStrategy[token] = newStrat;
            startingTokensPerShare[token] = getDepositTokensForShares(1e18);
            feeMultiple[token] = startingTokensPerShare[token];
        }
        emit SubjectUpdated("yak strategy", token);
    }

    function setFeePer10k(uint256 fee) external onlyOwnerExec {
        require(10_000 >= fee, "Fee too high");
        feePer10k = fee;
    }
}
