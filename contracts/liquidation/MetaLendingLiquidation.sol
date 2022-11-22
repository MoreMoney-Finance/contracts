// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../oracles/OracleAware.sol";
import "../roles/RoleAware.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../MetaLending.sol";
import "../roles/DependsOnMetaLending.sol";
import "../roles/DependsOnFeeRecipient.sol";
import "../roles/DependsOnOracleRegistry.sol";
import "../roles/DependsOnLiquidationProtected.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../roles/DependsOnUnderwaterLiquidator.sol";
import "../../interfaces/IFeeReporter.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/// Liquidation contract forMetaLending
contract MetaLendingLiquidation is
    RoleAware,
    DependsOnStableCoin,
    DependsOnMetaLending,
    DependsOnFeeRecipient,
    DependsOnUnderwaterLiquidator,
    DependsOnOracleRegistry,
    DependsOnLiquidationProtected,
    ReentrancyGuard,
    IFeeReporter,
    ERC721Holder,
    OracleAware
{
    using SafeERC20 for IERC20;

    mapping(address => uint256) public liquidationRewardPer10k;
    uint256 public defaultLiquidationRewardPer10k = (10 * 10_000) / 100;
    uint256 public defaultProtocolFeePer10k = (15 * 10_000) / 1000;
    mapping(address => uint256) public protocolFeePer10k;

    mapping(uint256 => uint256) public liquidationTstamp;

    uint256 public override viewAllFeesEver;

    constructor(address _roles) RoleAware(_roles) {
        _rolesPlayed.push(MINTER_BURNER);
        _rolesPlayed.push(TRANCHE_TRANSFERER);
        _rolesPlayed.push(FUND_TRANSFERER);
        _charactersPlayed.push(METALENDING_LIQUIDATION);
    }

    /// Run liquidation of a tranche
    /// Rebalancing bid must lift the tranche (with requested collateral removed) back
    /// above the minimum viable collateralization threshold
    /// If the rebalancing bid furthermore exceeds the value of requested collateral minus liquidation fee,
    /// the collateral is transferred to the liquidator and they are charged the rebalancing bid
    /// Fees going to the protocol are taken out of the rebalancing bid
    function liquidate(
        uint256 trancheId,
        uint256 collateralRequested,
        uint256 rebalancingBid,
        address recipient
    ) external nonReentrant {
        require(recipient != address(0), "Don't send to zero address");

        MetaLending lending = metaLending();
        Stablecoin stable = stableCoin();

        address oldOwner = lending.ownerOf(trancheId);
        require(
            !isLiquidationProtected(oldOwner),
            "Owner is liquidation protected"
        );

        require(!lending.isViable(trancheId), "Tranche not liquidatable");
        lending.collectYield(trancheId, address(stable), oldOwner);

        (uint256 bidTarget, uint256 protocolCut) = getBidTargetAndProtocolCut(
            trancheId,
            collateralRequested
        );
        require(
            rebalancingBid >= bidTarget,
            "Insuficient debt rebalancing bid"
        );

        stable.burn(msg.sender, rebalancingBid);
        stable.mint(address(this), rebalancingBid - protocolCut);

        // this checks for viability
        lending.repayAndWithdraw(
            trancheId,
            collateralRequested,
            rebalancingBid - protocolCut,
            recipient
        );

        stable.mint(feeRecipient(), protocolCut);
        viewAllFeesEver += protocolCut;

        liquidationTstamp[trancheId] = block.timestamp;
    }

    /// View bid target and protocol cut for a tranche id and requested amount of collateral
    function getBidTargetAndProtocolCut(
        uint256 trancheId,
        uint256 collateralRequested
    ) public returns (uint256, uint256) {
        MetaLending lending = metaLending();
        address token = lending.trancheToken(trancheId);

        uint256 requestedCollateralValue = _getValue(
            token,
            collateralRequested,
            address(stableCoin())
        );

        uint256 totalColValue = (lending.viewTargetCollateralAmount(trancheId) *
            requestedCollateralValue) / collateralRequested;

        uint256 bidTarget = viewBidTarget(trancheId, requestedCollateralValue);

        uint256 totalDebt = lending.trancheDebt(trancheId);
        uint256 protocolShare = viewProtocolSharePer10k(token);

        // Take protocol cut as portion of requested collateral value,
        // but not exceeding 40% of residual value of tranche after liquidation
        uint256 protocolCut = min(
            (protocolShare * requestedCollateralValue) / 10_000,
            totalColValue - requestedCollateralValue > totalDebt - bidTarget
                ? (40 *
                    ((totalColValue - requestedCollateralValue) -
                        (totalDebt - bidTarget))) / 100
                : 0
        );

        return (bidTarget, protocolCut);
    }

    function viewBidTarget(uint256 trancheId, uint256 requestedCollateralValue)
        public
        view
        returns (uint256)
    {
        MetaLending lending = metaLending();

        // minimum bid, accounting for surplus value going to liquidator
        uint256 bidTarget = ((10_000 -
            viewLiqSharePer10k(lending.trancheToken(trancheId))) *
            requestedCollateralValue) / 10_000;

        return bidTarget;
    }

    /// Special liquidation for underwater accounts (debt > value)
    /// Restricted to only trusted users, in case there is some vulnerability at play
    /// Of course other players can still call normal liquidation on underwater accounts
    /// And be compensated by the shortfall claims process
    function liquidateUnderwater(
        uint256 trancheId,
        address recipient,
        bytes calldata _data
    ) external nonReentrant {
        require(
            isUnderwaterLiquidator(msg.sender) ||
                disabler() == msg.sender ||
                owner() == msg.sender ||
                executor() == msg.sender,
            "Caller not authorized to liquidate underwater"
        );

        MetaLending lending = metaLending();
        lending.collectYield(trancheId, address(stableCoin()), recipient);
        uint256 debt = lending.trancheDebt(trancheId);
        uint256 value = lending.viewCollateralValue(trancheId);

        require(!lending.isViable(trancheId), "Tranche is not liquidatable");
        require(debt > value, "Tranche not underwater");

        metaLending().safeTransferFrom(
            metaLending().ownerOf(trancheId),
            recipient,
            trancheId,
            _data
        );
    }

    /// Set liquidation share per asset
    function setLiquidationRewardPer10k(address token, uint256 liqSharePer10k)
        external
        onlyOwnerExec
    {
        liquidationRewardPer10k[token] = liqSharePer10k;
        emit SubjectParameterUpdated("liq reward", token, liqSharePer10k);
    }

    /// Set liquidation share in default
    function setDefaultLiquidationRewardPer10k(uint256 liqSharePer10k)
        external
        onlyOwnerExec
    {
        defaultLiquidationRewardPer10k = liqSharePer10k;
        emit ParameterUpdated("default liq reward", liqSharePer10k);
    }

    /// Set protocol fee per asset
    function setProtcolFeePer10k(address token, uint256 protFeePer10k)
        external
        onlyOwnerExec
    {
        protocolFeePer10k[token] = protFeePer10k;
        emit SubjectParameterUpdated("protocol fee", token, protFeePer10k);
    }

    /// Set protocol fee in default
    function setProtocolFeePer10k(uint256 protFeePer10k)
        external
        onlyOwnerExec
    {
        defaultProtocolFeePer10k = protFeePer10k;
        emit ParameterUpdated("default protocol fee", protFeePer10k);
    }

    /// In an emergency, withdraw any tokens stranded in this contract's balance
    function rescueStrandedTokens(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwnerExec {
        require(recipient != address(0), "Don't send to zero address");

        IERC20(token).safeTransfer(recipient, amount);
    }

    /// Rescue any stranded native currency
    function rescueNative(uint256 amount, address recipient)
        external
        onlyOwnerExec
    {
        require(recipient != address(0), "Don't send to zero address");

        payable(recipient).transfer(amount);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return b;
        } else {
            return a;
        }
    }

    /// View liquidation share for a token
    function viewLiqSharePer10k(address token)
        public
        view
        returns (uint256 liqShare)
    {
        liqShare = liquidationRewardPer10k[token];
        if (liqShare == 0) {
            liqShare = defaultLiquidationRewardPer10k;
        }
    }

    /// View protocol share for a token
    function viewProtocolSharePer10k(address token)
        public
        view
        returns (uint256 protocolShare)
    {
        protocolShare = protocolFeePer10k[token];
        if (protocolShare == 0) {
            protocolShare = defaultProtocolFeePer10k;
        }
    }

    /// View liquidation fee for a token
    function viewLiquidationFeePer10k(address token)
        external
        view
        returns (uint256)
    {
        return viewProtocolSharePer10k(token) + viewLiqSharePer10k(token);
    }
}
