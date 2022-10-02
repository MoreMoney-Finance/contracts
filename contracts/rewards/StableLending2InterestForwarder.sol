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
    uint256 public interestLastForwarded;
    iMoney immutable imoney;
    uint256 public treasurySharePer10k = 7000;
    address public treasury = 0xc44A49eB7e0Db812382BE975e96AC5c03d308002;

    constructor(address _iMoney, address _roles) RoleAware(_roles) {
        interestLastForwarded = StableLending2(Roles(_roles).mainCharacters(STABLE_LENDING_2)).totalEarnedInterest();
        require(interestLastForwarded > 0, "interestLastForwarded must be greater than 0");
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
        uint256 delta = newInterest - interestLastForwarded;
        Stablecoin stable = stableCoin();
        stable.mint(address(imoney), delta * (10_000 - treasurySharePer10k) / 10_000);
        stable.mint(treasury, delta * treasurySharePer10k / 10_000);
        interestLastForwarded = newInterest;
    }

    function claimableInterest() public view returns (uint256) {
        return stableLending2().totalEarnedInterest() - interestLastForwarded;
    }

    function balanceOf(address user) external view returns (uint256) {
        return imoney.balanceOf(user) + viewPendingReward(user);
    }

    function viewPendingReward(address user) public view returns (uint256) {
        uint256 claimable = claimableInterest() * (10_000 - treasurySharePer10k) / 10_000;
        return imoney.viewPendingReward(user, claimable);
    }

    function deposit(uint256 amount) external {
        forwardInterest();
        imoney.depositFor(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        forwardInterest();
        imoney.withdrawFor(msg.sender, amount);
    }

    function setTreasurySharePer10k(uint256 share) external onlyOwnerExec {
        require(10_000 >= share, "excessive share");
        treasurySharePer10k = share;
    }

    function setTreasury(address t) external onlyOwnerExec {
        treasury = t;
    }
}
