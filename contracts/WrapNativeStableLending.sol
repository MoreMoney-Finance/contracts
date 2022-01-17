// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./roles/RoleAware.sol";
import "./roles/DependsOnStableLending.sol";
import "./roles/DependsOnStableCoin.sol";
import "../interfaces/IWETH.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract WrapNativeStableLending is
    DependsOnStableLending,
    DependsOnStableCoin,
    RoleAware,
    ERC721Holder
{
    using SafeERC20 for IWETH;
    IWETH public immutable wrappedNative;

    constructor(address _wrappedNative, address _roles) RoleAware(_roles) {
        _rolesPlayed.push(TRANCHE_TRANSFERER);
        _rolesPlayed.push(MINTER_BURNER);
        wrappedNative = IWETH(_wrappedNative);
    }

    receive() external payable {}

    fallback() external payable {}

    /// Mint a tranche denominated in wrapped native
    function mintDepositAndBorrow(
        address strategy,
        uint256 borrowAmount,
        address recipient
    ) external payable returns (uint256) {
        wrappedNative.deposit{value: msg.value}();
        wrappedNative.safeApprove(strategy, 0);
        wrappedNative.safeApprove(strategy, type(uint256).max);
        StableLending lending = stableLending();
        uint256 trancheId = lending.mintDepositAndBorrow(
            address(wrappedNative),
            strategy,
            msg.value,
            borrowAmount,
            recipient
        );

        lending.safeTransferFrom(address(this), msg.sender, trancheId);
        return trancheId;
    }

    /// Deposit native currency and borrow
    function depositAndBorrow(
        uint256 trancheId,
        uint256 borrowAmount,
        address recipient
    ) external payable {
        StableLending lending = stableLending();
        require(
            lending.isAuthorized(msg.sender, trancheId),
            "Not authorized to withdraw yield"
        );
        wrappedNative.deposit{value: msg.value}();

        lending.depositAndBorrow(trancheId, msg.value, borrowAmount, recipient);
    }

    /// Repay stable and withdraw native
    function repayAndWithdraw(
        uint256 trancheId,
        uint256 collateralAmount,
        uint256 repayAmount,
        address payable recipient
    ) external {
        StableLending lending = stableLending();
        require(
            lending.isAuthorized(msg.sender, trancheId),
            "Not authorized to withdraw yield"
        );

        Stablecoin stable = stableCoin();
        stable.burn(msg.sender, repayAmount);
        stable.mint(address(this), repayAmount);

        uint256 balanceBefore = wrappedNative.balanceOf(address(this));
        lending.repayAndWithdraw(
            trancheId,
            collateralAmount,
            repayAmount,
            address(this)
        );
        uint256 balanceDelta = wrappedNative.balanceOf(address(this)) -
            balanceBefore;
        wrappedNative.withdraw(balanceDelta);
        recipient.transfer(balanceDelta);
    }
}
