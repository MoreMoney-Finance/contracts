// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./roles/RoleAware.sol";
import "./roles/DependsOnStableLending2.sol";
import "./roles/DependsOnStableCoin.sol";
import "./StableLending2.sol";
import "../interfaces/IWETH.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract WrapNativeStableLending2 is
    DependsOnStableLending2,
    DependsOnStableCoin,
    RoleAware,
    ERC721Holder
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH;
    using SafeERC20 for Stablecoin;
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
        wrappedNative.safeIncreaseAllowance(strategy, msg.value);
        StableLending2 lending = stableLending2();
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
        StableLending2 lending = stableLending2();
        require(
            lending.isAuthorized(msg.sender, trancheId),
            "Not authorized to withdraw yield"
        );
        wrappedNative.deposit{value: msg.value}();

        address strategy = lending.viewCurrentHoldingStrategy(trancheId);
        wrappedNative.safeIncreaseAllowance(strategy, msg.value);
        lending.depositAndBorrow(trancheId, msg.value, borrowAmount, recipient);
    }

    /// Repay stable and withdraw native
    function repayAndWithdraw(
        uint256 trancheId,
        uint256 collateralAmount,
        uint256 repayAmount,
        address payable recipient
    ) external {
        StableLending2 lending = stableLending2();
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

        uint256 moneyBalance = stable.balanceOf(address(this));
        if (moneyBalance > 0) {
            stable.safeTransfer(recipient, moneyBalance);
        }
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
}
