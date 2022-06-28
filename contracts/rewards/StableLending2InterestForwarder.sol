// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../roles/RoleAware.sol";
import "../roles/DependsOnStableLending2.sol";
import "../roles/DependsOnStableCoin.sol";
import "./iMoney.sol";

contract StableLending2InterestForwarder is
    RoleAware,
    DependsOnStableLending2,
    DependsOnStableCoin,
    ReentrancyGuard
{
    uint256 interestLastForwarded;
    iMoney immutable imoney;

    constructor(address _iMoney, address _roles) RoleAware(_roles) {
        // require(
        //     StableLending2(Roles(_roles).mainCharacters(STABLE_LENDING_2))
        //         .totalEarnedInterest() == 0,
        //     "Initialize jointly with lending contract"
        // );
        imoney = iMoney(_iMoney);
        _rolesPlayed.push(MINTER_BURNER);
        _rolesPlayed.push(FUND_TRANSFERER);
    }

    function forwardAndRegisterInterest() external {
        forwardInterest();
        imoney.registerReward();
    }

    function forwardInterest() public nonReentrant {
        uint256 newInterest = stableLending2().totalEarnedInterest();
        stableCoin().mint(address(imoney), newInterest - interestLastForwarded);
        interestLastForwarded = newInterest;
    }

    function claimableInterest() public view returns (uint256) {
        return stableLending2().totalEarnedInterest() - interestLastForwarded;
    }

    function balanceOf(address user) external view returns (uint256) {
        return imoney.balanceOf(user) + viewPendingReward(user);
    }

    function viewPendingReward(address user) public view returns (uint256) {
        return imoney.viewPendingReward(user, claimableInterest());
    }

    function deposit(uint256 amount) external {
        forwardInterest();
        imoney.depositFor(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        forwardInterest();
        imoney.withdrawFor(msg.sender, amount);
    }
}
