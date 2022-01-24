// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// A vesting wrapper token
contract VestingWrapper is ERC20Permit, Ownable {
    using SafeERC20 for IERC20;
    IERC20 public immutable vestingToken;

    uint256 public vestingTime = 3 * 365 days;
    uint256 public vestingStart;

    // amounts of vesting token withdrawn by accounts
    mapping(address => uint256) public withdrawn;

    constructor(
        string memory _name,
        string memory _symbol,
        address _wrappedToken
    ) Ownable() ERC20(_name, _symbol) ERC20Permit(_symbol) {
        vestingToken = IERC20(_wrappedToken);
        vestingStart = block.timestamp + 30 days;
    }

    /////////////////////////////////// Owner ops

    /// Mint wrapper tokens to an array of recipients
    function mint(address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyOwner
    {
        require(recipients.length == amounts.length, "Mismatched arrays");
        for (uint256 i; recipients.length > i; i++) {
            _mint(recipients[i], amounts[i]);
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

    //////////////////////////////////////// User ops

    /// Burn wrapper token, withdrawing underlying wrapped tokens
    function burn(uint256 wrapperAmount) external {
        uint256 withdrawAmount = wrapper2vesting(wrapperAmount);

        require(
            vestedByAccount(msg.sender) >= withdrawAmount,
            "Withdrawing more than vested by acount"
        );

        withdrawn[msg.sender] += withdrawAmount;
        _burn(msg.sender, wrapperAmount);

        vestingToken.safeTransfer(msg.sender, withdrawAmount);
    }

    ///////////////////////////////////////// View functions

    /// How many vesting tokens are wrapped by an account
    function wrappedByAccount(address account) public view returns (uint256) {
        return wrapper2vesting(balanceOf(account));
    }

    /// How many vesting tokens an account is able to withdraw
    function vestedByAccount(address account) public view returns (uint256) {
        if (block.timestamp > vestingStart) {
            uint256 balance = balanceOf(account);
            uint256 currentClaim = wrapper2vesting(balance);
            uint256 alreadyWithdrawn = withdrawn[account];
            uint256 totalClaim = alreadyWithdrawn + currentClaim;

            uint256 timeDelta = block.timestamp - vestingStart;
            uint256 totalVested = min(totalClaim, (totalClaim * timeDelta) / vestingTime);
            return min(currentClaim, totalVested - alreadyWithdrawn);
        } else {
            return 0;
        }
    }

    /// Burnable amount
    function burnableByAccount(address account)
        external
        view
        returns (uint256)
    {
        return vesting2wrapper(vestedByAccount(account));
    }

    /// Convert wrapper token amount to vesting tokens
    function wrapper2vesting(uint256 wrapperAmount)
        public
        view
        returns (uint256)
    {
        uint256 supply = totalSupply();
        if (supply > 0) {
            return
                (wrapperAmount * vestingToken.balanceOf(address(this))) /
                supply;
        } else {
            return 0;
        }
    }

    /// Convert vesting token amount to wrapper
    function vesting2wrapper(uint256 vestingAmount)
        public
        view
        returns (uint256)
    {
        uint256 balance = vestingToken.balanceOf(address(this));
        if (balance > 0) {
            return (totalSupply() * vestingAmount) / balance;
        } else {
            return 0;
        }
    }

    ///////////////////////////////////////////// Internals

    /// Min of two numbers
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a >= b) {
            return b;
        } else {
            return a;
        }
    }

    /// Proportionally re-assign withdrawn amounts to new owner
    /// (so token transfer doesn't speed up vesting)
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (amount > 0 && from != address(0) && to != address(0)) {
            uint256 withdrawnFrom = withdrawn[from];
            uint256 balanceFrom = balanceOf(from);

            uint256 migrateAmount = (withdrawnFrom * amount) / balanceFrom;
            withdrawn[from] -= migrateAmount;
            withdrawn[to] += migrateAmount;
        }
    }

    function setVestingTime(uint256 time) external onlyOwner {
        vestingTime = time;
    }

    function setVestingStart(uint256 startTime) external onlyOwner {
        vestingStart = startTime;
    }
}
