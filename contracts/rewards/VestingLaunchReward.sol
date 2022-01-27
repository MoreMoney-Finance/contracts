// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract VestingLaunchReward is Ownable {
    using SafeERC20 for IERC20;

    // total amount of vesting toime
    uint256 public vestingTime = 100 days;
    // when the vesting starts
    uint256 public vestingStart;

    // how much a user can still withdraw
    mapping(address => uint256) public balanceOf;
    // how much a user has withdrawn
    mapping(address => uint256) public withdrawn;

    IERC20 public immutable vestingToken;

    constructor(address _vestingToken) {
        vestingStart = block.timestamp - (10 days);
        vestingToken = IERC20(_vestingToken);
    }

    /// Assign claims to an array of recipients
    function mint(address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyOwner
    {
        require(recipients.length == amounts.length, "Mismatched arrays");
        for (uint256 i; recipients.length > i; i++) {
            balanceOf[recipients[i]] = amounts[i];
        }
    }

    /// Withdraw claimable amounts
    function burn(uint256 amount) external {
        require(
            burnableByAccount(msg.sender) >= amount,
            "Trying to withdraw too much"
        );
        withdrawn[msg.sender] += amount;
        balanceOf[msg.sender] -= amount;
        vestingToken.safeTransfer(msg.sender, amount);
    }

    /// How much a user can claim
    function burnableByAccount(address account) public view returns (uint256) {
        uint256 timeDelta = block.timestamp - vestingStart;

        uint256 balance = balanceOf[account];
        uint256 alreadyWithdrawn = withdrawn[account];

        uint256 totalClaim = balance + alreadyWithdrawn;

        uint256 totalVested = min(
            totalClaim,
            (totalClaim * timeDelta) / vestingTime
        );
        return min(balance, totalVested - alreadyWithdrawn);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a >= b) {
            return b;
        } else {
            return a;
        }
    }

    /// Rescue stranded funds
    function rescueFunds(
        address token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        IERC20(token).safeTransfer(recipient, amount);
    }

    function setVestingTime(uint256 time) external onlyOwner {
        vestingTime = time;
    }

    function setVestingStart(uint256 startTime) external onlyOwner {
        vestingStart = startTime;
    }
}
