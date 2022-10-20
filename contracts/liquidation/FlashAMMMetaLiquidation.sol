// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "../roles/RoleAware.sol";
import "../roles/DependsOnStableCoin.sol";
import "../roles/DependsOnMetaLending.sol";
import "../roles/DependsOnMetaLendingLiquidation.sol";
import "../oracles/OracleAware.sol";

import "../../interfaces/IPlatypusRouter01.sol";

abstract contract FlashAMMMetaLiquidation is
    IERC3156FlashBorrower,
    RoleAware,
    DependsOnStableCoin,
    DependsOnMetaLending,
    DependsOnMetaLendingLiquidation,
    OracleAware
{
    using SafeERC20 for IERC20;

    mapping(address => int128) public stableIndices;
    address internal immutable intermediaryToken;
    address internal immutable defaultStable;
    address usdcToken = 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664;
    IPlatypusRouter01 platypusRouter =
        IPlatypusRouter01(0x73256EC7575D999C360c1EeC118ECbEFd8DA7D12);

    constructor(
        address _intermediaryToken,
        address _defaultStable,
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
    }

    function liquidate(
        uint256 trancheId,
        address router,
        address recipient
    ) external {
        MetaLending lending = metaLending();
        address token = lending.trancheToken(trancheId);

        Stablecoin stable = stableCoin();
        uint256 extantCollateral = lending.viewTargetCollateralAmount(
            trancheId
        );
        uint256 extantCollateralValue = _getValue(
            token,
            extantCollateral,
            address(stable)
        );

        uint256 requestedColVal;
        {
            uint256 ltvPer10k = oracleRegistry().borrowablePer10ks(token);

            // requested collateral value is the mean of total debt and the minimum
            // necessary to restore minimum col ratio
            uint256 yield = lending.viewYield(trancheId, address(stable));
            uint256 debt = lending.trancheDebt(trancheId);
            debt = yield > debt ? 0 : debt - yield;
            requestedColVal =
                (debt +
                    (10_000 * debt - ltvPer10k * extantCollateralValue) /
                    (10_000 - ltvPer10k)) /
                2;
        }

        stable.flashLoan(
            this,
            address(stable),
            (1000 *
                stableLendingLiquidation2().viewBidTarget(
                    trancheId,
                    requestedColVal
                )) / 984,
            abi.encode(
                trancheId,
                (extantCollateral * requestedColVal) / extantCollateralValue,
                token,
                router
            )
        );

        IERC20(stable).safeTransfer(recipient, stable.balanceOf(address(this)));
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
        stableLendingLiquidation2().liquidate(
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
            address(platypusRouter),
            stableBalance
        );

        address[] memory platypusTokenPath;
        address[] memory platypusPoolPath;
        if (stableToken == usdcToken) {
            platypusTokenPath = new address[](2);
            platypusTokenPath[0] = usdcToken;
            platypusTokenPath[1] = address(stableCoin());

            address moneyPool = 0x27912AE6Ba9a54219d8287C3540A8969FF35500B;
            platypusPoolPath = new address[](1);
            platypusPoolPath[0] = moneyPool;
        } else {
            platypusTokenPath = new address[](3);
            platypusTokenPath[0] = stableToken;
            platypusTokenPath[1] = usdcToken;
            platypusTokenPath[2] = address(stableCoin());

            address mainUSDPool = 0x66357dCaCe80431aee0A7507e2E361B7e2402370;
            address moneyPool = 0x27912AE6Ba9a54219d8287C3540A8969FF35500B;
            platypusPoolPath = new address[](2);
            platypusPoolPath[0] = mainUSDPool;
            platypusPoolPath[1] = moneyPool;
        }
        platypusRouter.swapTokensForTokens(
            platypusTokenPath,
            platypusPoolPath,
            stableBalance,
            0,
            address(this),
            block.timestamp + 1
        );
    }
}
