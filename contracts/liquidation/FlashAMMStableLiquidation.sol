// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "../roles/RoleAware.sol";
import "../roles/DependsOnStableCoin.sol";
import "../roles/DependsOnStableLending.sol";
import "../roles/DependsOnCurvePool.sol";
import "../roles/DependsOnStableLendingLiquidation.sol";
import "../oracles/OracleAware.sol";

import "../../interfaces/ICurvePool.sol";
import "../../interfaces/ICurveZap.sol";

abstract contract FlashAMMStableLiquidation is
    IERC3156FlashBorrower,
    RoleAware,
    DependsOnStableCoin,
    DependsOnCurvePool,
    DependsOnStableLending,
    DependsOnStableLendingLiquidation,
    OracleAware
{
    using SafeERC20 for IERC20;

    mapping(address => int128) public stableIndices;
    address internal immutable intermediaryToken;
    address internal immutable defaultStable;
    ICurveZap internal immutable curveZap;

    constructor(
        address _intermediaryToken,
        address _defaultStable,
        address _curveZap,
        address[] memory stables,
        address _roles
    ) RoleAware(_roles) {
        address stable = Roles(_roles).mainCharacters(STABLECOIN);
        Stablecoin(stable).approve(stable, type(uint256).max);

        for (uint256 i = 2; stables.length + 2 > i; i++) {
            stableIndices[stables[i - 2]] = int128(int256(i));
        }
        stableIndices[stable] = 1;

        intermediaryToken = _intermediaryToken;
        defaultStable = _defaultStable;
        curveZap = ICurveZap(_curveZap);
    }

    function liquidate(
        uint256 trancheId,
        address router,
        address recipient
    ) external {
        Stablecoin stable = stableCoin();

        (
            uint256 bidTarget,
            uint256 collateralRequest,
            address token
        ) = getBidAndRequest(trancheId);
        stable.flashLoan(
            this,
            address(stable),
            bidTarget,
            abi.encode(trancheId, collateralRequest, token, router)
        );

        IERC20(stable).safeTransfer(recipient, stable.balanceOf(address(this)));
    }

    function getBidAndRequest(uint256 trancheId)
        internal
        returns (
            uint256,
            uint256,
            address
        )
    {
        StableLending lending = stableLending();
        address token = lending.trancheToken(trancheId);

        uint256 extantCollateral = lending.viewTargetCollateralAmount(
            trancheId
        );

        uint256 extantCollateralValue = _getValue(
            token,
            extantCollateral,
            address(stableCoin())
        );

        uint256 requestedColVal;

        uint256 ltvPer10k = oracleRegistry().borrowablePer10ks(token);

        // requested collateral value is the mean of total debt and the minimum
        // necessary to restore minimum col ratio
        uint256 debt = lending.trancheDebt(trancheId);
        requestedColVal =
            (debt +
                (10_000 * debt - ltvPer10k * extantCollateralValue) /
                (10_000 - ltvPer10k)) /
            2;

        uint256 bidTarget = (1000 *
            stableLendingLiquidation().viewBidTarget(
                trancheId,
                requestedColVal
            )) / 984;

        if (
            debt - bidTarget >
            ((extantCollateralValue - requestedColVal) * ltvPer10k) / 10_000
        ) {
            uint256 collateralRequest = (extantCollateral * requestedColVal) /
                extantCollateralValue;

            return (bidTarget, min(extantCollateral, collateralRequest), token);

        } else {
            uint256 correspondingCollateral = (extantCollateral * debt) /
                extantCollateralValue;
            uint256 requestedCollateral = (correspondingCollateral *
                requestedColVal) / bidTarget;

            return (debt, min(extantCollateral, requestedCollateral), token);
        }
    }

    function onFlashLoan(
        address,
        address,
        uint256 amount,
        uint256,
        bytes calldata data
    ) external override returns (bytes32) {
        (
            uint256 trancheId,
            uint256 collateralRequested,
            address token,
            address router
        ) = abi.decode(data, (uint256, uint256, address, address));
        stableLendingLiquidation().liquidate(
            trancheId,
            collateralRequested,
            amount,
            address(this)
        );

        // TODO add unwrap to strategies? or build it into the choice of liquidation flash loan contract? probably easier
        // so we would have an abstract function that gets called to unwrap & unwind a token balance

        unwrapAndUnwind(token, router);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function resetApproval() external {
        Stablecoin stable = stableCoin();
        stable.approve(address(stable), type(uint256).max);
    }

    function unwrapAndUnwind(address token, address router) internal virtual;

    function unwind(address token, address router) internal virtual {
        uint256 balance = IERC20(token).balanceOf(address(this));

        address stableToken;
        uint256 stableBalance;
        if (stableIndices[token] > 0) {
            stableToken = token;
            stableBalance = balance;
        } else {
            address[] memory path;
            stableToken = defaultStable;
            if (token == intermediaryToken) {
                path = new address[](2);
                path[0] = token;
                path[1] = stableToken;
            } else {
                path = new address[](3);
                path[0] = token;
                path[1] = intermediaryToken;
                path[2] = stableToken;
            }

            IERC20(token).safeIncreaseAllowance(router, balance);
            uint256[] memory amountsOut = IUniswapV2Router02(router)
                .swapExactTokensForTokens(
                    balance,
                    0,
                    path,
                    address(this),
                    block.timestamp + 1
                );

            stableBalance = amountsOut[amountsOut.length - 1];
        }

        IERC20(stableToken).safeIncreaseAllowance(
            address(curveZap),
            stableBalance
        );
        curveZap.exchange_underlying(
            curvePool(),
            stableIndices[stableToken] - 1,
            0,
            stableBalance,
            0,
            address(this)
        );
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a >= b) {
            return b;
        } else {
            return a;
        }
    }
}
