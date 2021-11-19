// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./oracles/OracleAware.sol";
import "./roles/RoleAware.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IsolatedLending.sol";
import "./roles/DependsOnStableCoin.sol";
import "./roles/DependsOnIsolatedLending.sol";
import "./roles/DependsOnFeeRecipient.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// Liquidation contract for IsolatedLending
contract IsolatedLendingLiquidation is
    RoleAware,
    DependsOnStableCoin,
    DependsOnIsolatedLending,
    DependsOnFeeRecipient,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    mapping(address => uint256) public liquidationRewardPer10k;
    uint256 public defaultLiquidationRewardPer10k = (3 * 10_000) / 100;
    uint256 public defaultProtocolFeePer10k = (15 * 10_000) / 100;
    mapping(address => uint256) public protocolFeePer10k;

    constructor(address _roles) RoleAware(_roles) {
        _rolesPlayed.push(LIQUIDATOR);
        _rolesPlayed.push(FUND_TRANSFERER);
    }

    /// Retrieve liquidatability, disbursing yield and updating oracles
    function getLiquidatability(uint256 trancheId)
        internal
        returns (
            bool,
            bool,
            uint256,
            uint256
        )
    {
        IsolatedLending lending = isolatedLending();
        lending.collectYield(
            trancheId,
            address(stableCoin()),
            lending.ownerOf(trancheId)
        );
        uint256 debt = lending.trancheDebt(trancheId);

        address trancheToken = lending.trancheToken(trancheId);
        uint256 liqShare = liquidationRewardPer10k[trancheToken];
        if (liqShare == 0) {
            liqShare = defaultLiquidationRewardPer10k;
        }

        uint256 liquidatorCut = (liqShare * debt) / 10_000;

        // The collateral returned to previous owner
        uint256 value = lending.viewCollateralValue(trancheId);
        uint256 collateralReturn = value >= debt + liquidatorCut
            ? (lending.viewTargetCollateralAmount(trancheId) *
                (value - debt - liquidatorCut)) / value
            : 0;

        uint256 protocolShare = protocolFeePer10k[trancheToken];
        if (protocolShare == 0) {
            protocolShare = defaultProtocolFeePer10k;
        }

        uint256 protocolCollateral = (collateralReturn * protocolShare) /
            10_000;

        return (
            !lending.isViable(trancheId),
            value >= debt + liquidatorCut,
            collateralReturn - protocolCollateral,
            protocolCollateral
        );
    }

    /// Run liquidation of a tranche
    /// Rebalancing bid must lift the tranche back above viable collateralization threshold
    /// If so, the position (minus excess value returned to old owner) gets transferred to liquidator
    function liquidate(
        uint256 trancheId,
        uint256 rebalancingBid,
        address recipient,
        bytes calldata _data
    ) external nonReentrant {
        (
            bool _liquidatable,
            ,
            uint256 collateralReturn,
            uint256 protocolCollateral
        ) = getLiquidatability(trancheId);
        require(_liquidatable, "Tranche is not liquidatable");

        Stablecoin stable = stableCoin();
        IsolatedLending lending = isolatedLending();

        stable.burn(msg.sender, rebalancingBid);
        stable.mint(address(this), rebalancingBid);

        // first take ownership of tranche
        address oldOwner = lending.ownerOf(trancheId);
        lending.liquidateTo(trancheId, address(this), "");

        // these both check for viability
        lending.repayAndWithdraw(
            trancheId,
            collateralReturn,
            rebalancingBid,
            oldOwner
        );
        lending.repayAndWithdraw(
            trancheId,
            protocolCollateral,
            0,
            feeRecipient()
        );

        // finally send to new recipient
        lending.liquidateTo(trancheId, recipient, _data);
    }

    /// Special liquidation for underwater accounts (debt > value)
    /// Restricted to only trusted users, in case there is some vulnerability at play
    function liquidateUnderwater(
        uint256 trancheId,
        address recipient,
        bytes calldata _data
    ) external nonReentrant onlyOwnerExecDisabler {
        (bool _liquidatable, bool isUnderwater, , ) = getLiquidatability(
            trancheId
        );
        require(_liquidatable, "Tranche is not liquidatable");
        require(isUnderwater, "Tranche not underwater");

        isolatedLending().liquidateTo(trancheId, recipient, _data);
    }

    /// Set liquidation share per asset
    function setLiquidationRewardPer10k(address token, uint256 liqSharePer10k)
        external
        onlyOwnerExecDisabler
    {
        liquidationRewardPer10k[token] = liqSharePer10k;
    }

    /// Set liquidation share in default
    function setDefaultLiquidationRewardPer10k(uint256 liqSharePer10k)
        external
        onlyOwnerExec
    {
        defaultLiquidationRewardPer10k = liqSharePer10k;
    }

    /// Set protocol fee per asset
    function setProtcolFeePer10k(address token, uint256 protFeePer10k)
        external
        onlyOwnerExecDisabler
    {
        protocolFeePer10k[token] = protFeePer10k;
    }

    /// Set protocol fee in default
    function setProtocolFeePer10k(uint256 protFeePer10k)
        external
        onlyOwnerExec
    {
        defaultProtocolFeePer10k = protFeePer10k;
    }

    /// In an emergency, withdraw any tokens stranded in this contract's balance
    function rescueStrandedTokens(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwnerExec {
        IERC20(token).safeTransfer(recipient, amount);
    }

    /// Rescue any stranded native currency
    function rescueNative(uint256 amount, address recipient)
        external
        onlyOwnerExec
    {
        payable(recipient).transfer(amount);
    }
}
