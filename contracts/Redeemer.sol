// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./roles/RoleAware.sol";
import "./roles/DependsOnTrancheIDService.sol";
import "../interfaces/IWETH.sol";
import "./StableLending.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../interfaces/ICurveZap.sol";
import "./roles/DependsOnCurvePool.sol";

contract Redeemer is
    RoleAware,
    DependsOnTrancheIDService,
    OracleAware,
    DependsOnStableCoin,
    DependsOnCurvePool
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    ICurveZap public immutable curveZap;

    EnumerableSet.AddressSet internal approvedTargetTokens;

    mapping(address => int128) public intermediaryIndex;

    constructor(
        address _curveZap,
        address[] memory _approvedTargetTokens,
        int128[] memory _intermediaryIndices,
        address _roles
    ) RoleAware(_roles) {
        _rolesPlayed.push(TRANCHE_TRANSFERER);
        _rolesPlayed.push(MINTER_BURNER);

        for (uint256 i; _approvedTargetTokens.length > i; i++) {
            address token = _approvedTargetTokens[i];
            approvedTargetTokens.add(token);
            intermediaryIndex[token] = _intermediaryIndices[i];
            curveZap = ICurveZap(_curveZap);
        }
    }

    function redeem(uint256 trancheId, uint256 percentage)
        external
        onlyOwnerExecDisabler
    {
        StableLending lendingContract = StableLending(
            trancheIdService().viewTrancheContractByID(trancheId)
        );
        address token = lendingContract.trancheToken(trancheId);

        Stablecoin stable = stableCoin();

        uint256 targetDebt = (percentage *
            lendingContract.trancheDebt(trancheId)) / 100;
        stable.mint(address(this), targetDebt);
        uint256 valuePer1e18 = _getValue(token, 1e18, address(stable));
        uint256 targetCollateral = (995 * targetDebt * 1e18) /
            valuePer1e18 /
            1000;

        lendingContract.repayAndWithdraw(
            trancheId,
            targetCollateral,
            targetDebt,
            address(this)
        );

        uint256 colBalance = IERC20(token).balanceOf(address(this));

            int128 idx = intermediaryIndex[token];
            require(idx > 0, "Not a valid intermediary");
            IERC20(token).safeIncreaseAllowance(
                address(curveZap),
                colBalance
            );
            curveZap.exchange_underlying(
                curvePool(),
                idx,
                0,
                colBalance,
                targetDebt,
                address(this)
            );

        stable.burn(address(this), targetDebt);
        IERC20(stable).safeTransfer(msg.sender, stable.balanceOf(address(this)));
    }
}
