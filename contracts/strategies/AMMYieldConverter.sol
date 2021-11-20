// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../roles/DependsOnStrategyRegistry.sol";
import "../roles/DependsOnFeeRecipient.sol";
import "../roles/RoleAware.sol";
import "../roles/DependsOnStableCoin.sol";
import "./YieldConversionStrategy.sol";
import "../oracles/OracleAware.sol";

contract AMMYieldConverter is
    DependsOnStrategyRegistry,
    OracleAware,
    DependsOnStableCoin,
    DependsOnFeeRecipient,
    ReentrancyGuard
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    EnumerableSet.AddressSet routers;
    EnumerableSet.AddressSet approvedTargetTokens;

    constructor(
        address[] memory _routers,
        address[] memory _approvedTargetTokens,
        address _roles
    ) RoleAware(_roles) {
        for (uint256 i; _routers.length > i; i++) {
            routers.add(_routers[i]);
        }
        for (uint256 i; _approvedTargetTokens.length > i; i++) {
            approvedTargetTokens.add(_approvedTargetTokens[i]);
        }

        _rolesPlayed.push(MINTER_BURNER);
    }

    /// Perform a complet harvest, from retrieving the reward token
    /// to swapping it on AMM for a stablecoin
    /// and then converting the yield with minted stable
    function harvest(
        address payable strategyAddress,
        address yieldBearingToken,
        address router,
        address[] calldata path
    ) external nonReentrant {
        require(
            strategyRegistry().enabledStrategy(strategyAddress),
            "Not an approved strategy"
        );
        require(routers.contains(router), "Not an approved router");

        YieldConversionStrategy strategy = YieldConversionStrategy(
            strategyAddress
        );

        strategy.harvestPartially(yieldBearingToken);

        uint256 rewardReserve = strategy.currentTalliedRewardReserve();

        address stable = address(stableCoin());
        uint256 targetBid = (_getValue(
            yieldBearingToken,
            rewardReserve,
            stable
        ) * strategy.minimumBidPer10k()) / 10_000;

        address endToken = path[path.length - 1];
        require(
            endToken == stable || approvedTargetTokens.contains(endToken),
            "Not an approved target token"
        );

        uint256 ammTarget = targetBid;
        if (endToken != stable) {
            uint256 conversionFactor = _getValue(endToken, 1e18, stable);
            ammTarget = (targetBid * 1e18) / conversionFactor;
        }

        uint256[] memory amountsOut = IUniswapV2Router02(router).getAmountsOut(
            rewardReserve,
            path
        );

        require(
            amountsOut[amountsOut.length - 1] >= ammTarget,
            "Insufficient output from swap"
        );

        stableCoin().mint(address(this), targetBid);

        strategy.convertReward2Stable(rewardReserve, targetBid);
        strategy.tallyHarvestBalance(yieldBearingToken);

        IERC20(path[0]).approve(router, rewardReserve);
        IUniswapV2Router02(router).swapExactTokensForTokens(
            rewardReserve,
            ammTarget,
            path,
            // TODO: switch this out for liquidity provision for our stable once it's ready
            feeRecipient(),
            block.timestamp + 1
        );
    }

    function addRouter(address router) external onlyOwnerExec {
        routers.add(router);
    }

    function approveTargetToken(address token) external onlyOwnerExec {
        approvedTargetTokens.add(token);
    }

    function removeRouter(address router) external onlyOwnerExecDisabler {
        routers.remove(router);
    }

    function removeTargetToken(address token) external onlyOwnerExecDisabler {
        approvedTargetTokens.remove(token);
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

    function viewRouters() external view returns (address[] memory) {
        return routers.values();
    }

    function viewApprovedTargetTokens()
        external
        view
        returns (address[] memory)
    {
        return approvedTargetTokens.values();
    }
}
