// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../roles/DependsOnStrategyRegistry.sol";
import "../roles/DependsOnFeeRecipient.sol";
import "../roles/DependsOnCurvePool.sol";
import "../roles/RoleAware.sol";
import "../roles/DependsOnStableCoin.sol";
import "./MultiYieldConversionStrategy.sol";
import "../oracles/OracleAware.sol";

import "../../interfaces/ICurvePool.sol";
import "../../interfaces/ICurveZap.sol";
import "../../interfaces/ICurveFactory.sol";

contract MultiAMMYieldConverter is
    DependsOnStrategyRegistry,
    OracleAware,
    DependsOnStableCoin,
    DependsOnFeeRecipient,
    DependsOnCurvePool,
    ReentrancyGuard
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    ICurveZap public immutable curveZap;

    EnumerableSet.AddressSet internal routers;
    EnumerableSet.AddressSet internal approvedTargetTokens;
    ICurvePool public constant usdcPool = ICurvePool(0x3a43A5851A3e3E0e25A3c1089670269786be1577);

    mapping(address => int128) public intermediaryIndex;

    constructor(
        address _curveZap,
        address[] memory _routers,
        address[] memory _approvedTargetTokens,
        int128[] memory _intermediaryIndices,
        address _roles
    ) RoleAware(_roles) {
        for (uint256 i; _routers.length > i; i++) {
            routers.add(_routers[i]);
        }
        for (uint256 i; _approvedTargetTokens.length > i; i++) {
            address token = _approvedTargetTokens[i];
            approvedTargetTokens.add(token);
            intermediaryIndex[token] = _intermediaryIndices[i];
        }

        _rolesPlayed.push(MINTER_BURNER);
        curveZap = ICurveZap(_curveZap);
    }

    /// Perform a complet harvest, from retrieving the reward token
    /// to swapping it on AMM for a stablecoin
    /// and then converting the yield with minted stable
    function harvest(
        address payable strategyAddress,
        address rewardToken,
        address yieldBearingToken,
        address router,
        address[] calldata path
    ) external nonReentrant {
        require(
            strategyRegistry().enabledStrategy(strategyAddress),
            "Not an approved strategy"
        );
        require(routers.contains(router), "Not an approved router");

        MultiYieldConversionStrategy strategy = MultiYieldConversionStrategy(
            strategyAddress
        );

        strategy.harvestPartially(yieldBearingToken);

        uint256 rewardReserve = strategy.rewardBalanceAccountedFor(
            IERC20(rewardToken)
        );

        Stablecoin stable = stableCoin();

        uint256 value = _getValue(rewardToken, rewardReserve, address(stable));
        uint256 targetBid = 2 + (value * strategy.minimumBidPer10k()) / 10_000;

        stable.mint(address(this), targetBid);

        strategy.convertReward2Stable(
            IERC20(rewardToken),
            rewardReserve,
            targetBid
        );

        address[] memory tokens = strategy.viewAllApprovedTokens();
        for (uint256 i; tokens.length > i; i++) {
            strategy.tallyHarvestBalance(tokens[i]);
        }

        address endToken = rewardToken;

        if (rewardToken == 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E) {
            // special case for USDC
            IERC20(rewardToken).safeIncreaseAllowance(address(usdcPool), rewardReserve);
            usdcPool.exchange(1, 0, rewardReserve, rewardReserve * 994 / 1000);
            endToken = 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664;
        } else if (!approvedTargetTokens.contains(rewardToken)) {

            endToken = path[path.length - 1];
            require(
                endToken == address(stable) ||
                    approvedTargetTokens.contains(endToken),
                "Not an approved target token"
            );

            uint256 ammTarget = targetBid;
            if (endToken != address(stable)) {
                uint256 conversionFactor = _getValue(
                    endToken,
                    1e18,
                    address(stable)
                );
                ammTarget = (targetBid * 1e18) / conversionFactor;
            }

            uint256[] memory amountsOut = IUniswapV2Router02(router)
                .getAmountsOut(rewardReserve, path);

            require(
                amountsOut[amountsOut.length - 1] >= ammTarget,
                "Insufficient output from swap"
            );

            IERC20(path[0]).safeIncreaseAllowance(router, rewardReserve);
            IUniswapV2Router02(router).swapExactTokensForTokens(
                rewardReserve,
                ammTarget,
                path,
                address(this),
                block.timestamp + 1
            );
        }

        if (endToken != address(stable)) {
            int128 idx = intermediaryIndex[endToken];
            require(idx > 0, "Not a valid intermediary");
            uint256 endBalance = IERC20(endToken).balanceOf(address(this)); 
            IERC20(endToken).safeIncreaseAllowance(
                address(curveZap),
                endBalance
            );
            curveZap.exchange_underlying(
                curvePool(),
                idx,
                0,
                endBalance,
                targetBid,
                address(this)
            );
        }

        uint256 balance = stable.balanceOf(address(this));
        if (balance > targetBid) {
            uint256 disburse = (balance - targetBid) / 2;
            stable.mint(feeRecipient(), disburse);
            stable.mint(msg.sender, disburse);
        }
        stable.burn(address(this), balance);
    }

    function isHarvestable(
        address payable strategyAddress,
        address rewardToken,
        address router,
        address[] calldata path
    ) external view returns (bool harvestable, uint256 expectedReward) {
        MultiYieldConversionStrategy strategy = MultiYieldConversionStrategy(
            strategyAddress
        );

        uint256 rewardReserve = strategy.rewardBalanceAccountedFor(
            IERC20(rewardToken)
        );

        if (1e18 > rewardReserve) {
            rewardReserve = 1e18;
        }

        Stablecoin stable = stableCoin();

        uint256 value = _viewValue(rewardToken, rewardReserve, address(stable));
        uint256 targetBid = 2 + (value * strategy.minimumBidPer10k()) / 10_000;

        address endToken = path[path.length - 1];
        require(
            endToken == address(stable) ||
                approvedTargetTokens.contains(endToken),
            "Not an approved target token"
        );

        uint256 ammTarget = targetBid;
        if (endToken != address(stable)) {
            uint256 conversionFactor = _viewValue(
                endToken,
                1e18,
                address(stable)
            );
            ammTarget = (targetBid * 1e18) / conversionFactor;
        }

        uint256[] memory amountsOut = IUniswapV2Router02(router).getAmountsOut(
            rewardReserve,
            path
        );

        if (ammTarget > amountsOut[amountsOut.length - 1]) {
            return (false, 0);
        } else {
            if (endToken != address(stable)) {
                int128 idx = intermediaryIndex[endToken];
                require(idx > 0, "Not a valid intermediary");

                uint256 stableOut = ICurvePool(curvePool()).get_dy_underlying(
                    idx,
                    0,
                    amountsOut[amountsOut.length - 1]
                );
                return (
                    stableOut >= targetBid,
                    stableOut > targetBid ? stableOut - targetBid : 0
                );
            } else {
                return (true, amountsOut[amountsOut.length - 1] - ammTarget);
            }
        }
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
