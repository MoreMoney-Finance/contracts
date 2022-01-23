// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// A vesting wrapper token
contract VestingWrapper is ERC20Permit, Ownable {
    using SafeERC20 for IERC20;
    IERC20 public immutable vestingToken;

    // how many wrapped tokens the entire system vests per second
    uint256 public vestingRate;
    // total amount vested by existing accounts
    uint256 public totalVested;
    // timestamp of last update
    uint256 public totalVestedLastUpdated;
    // all the vesting token withdrawn by holders so far
    uint256 public totalWithdrawn = 0;

    // amounts of vesting token withdrawn by accounts
    mapping(address => uint256) public withdrawn;

    constructor(
        string memory _name,
        string memory _symbol,
        address _wrappedToken
    ) Ownable() ERC20(_name, _symbol) ERC20Permit(_symbol) {
        vestingToken = IERC20(_wrappedToken);
        totalVestedLastUpdated = block.timestamp;
    }

    /////////////////////////////////// Owner ops

    /// Mint wrapper tokens to an array of recipients
    function mint(address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyOwner
    {
        updatedTotalVested();
        require(recipients.length == amounts.length, "Mismatched arrays");
        for (uint256 i; recipients.length > i; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }

    /// Set the vesting rate per second, based on an instant vesting amount,
    /// the desired vesting time and current vesting token balance
    function setVestingSchedule(
        uint256 instantVestingTotal,
        uint256 vestingTime
    ) external onlyOwner {
        updatedTotalVested();

        uint256 allVesting = allVestingEver();
        require(
            allVesting >= totalVested + instantVestingTotal,
            "starting vesting too high"
        );
        totalVested += instantVestingTotal;

        vestingRate = (allVesting - totalVested) / vestingTime;
    }

    /// Rescue stranded funds
    function rescueFunds(address token, address recipient, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(recipient, amount);
    }

    //////////////////////////////////////// User ops

    /// Burn wrapper token, withdrawing underlying wrapped tokens
    function burn(uint256 wrapperAmount) external {
        updateTotalVested();

        uint256 withdrawAmount = wrapper2vesting(wrapperAmount);

        require(
            _vestedByAccount(msg.sender, totalVested) >= withdrawAmount,
            "Withdrawing more than vested by acount"
        );

        _burn(msg.sender, wrapperAmount);
        withdrawn[msg.sender] += withdrawAmount;
        totalWithdrawn += withdrawAmount;

        vestingToken.safeTransfer(msg.sender, withdrawAmount);
    }

    /// Update the total vested amount
    function updateTotalVested() public {
        totalVested = updatedTotalVested();
        totalVestedLastUpdated = block.timestamp;
    }

    ///////////////////////////////////////// View functions

    /// Calculate updated total vested amount
    function updatedTotalVested() public view returns (uint256) {
        uint256 additionalVesting = (block.timestamp - totalVestedLastUpdated) *
            vestingRate;
        return min(totalVested + additionalVesting, allVestingEver());
    }

    /// How many vesting tokens are wrapped by an account
    function wrappedByAccount(address account) public view returns (uint256) {
        return wrapper2vesting(balanceOf(account));
    }

    /// How many vesting tokens an account is able to withdraw
    function vestedByAccount(address account) public view returns (uint256) {
        return _vestedByAccount(account, updatedTotalVested());
    }

    /// Burnable amount
    function burnableByAccount(address account) external view returns (uint256) {
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

    /// All vesting tokens (including those already withdrawn)
    function allVestingEver() public view returns (uint256) {
        return totalWithdrawn + vestingToken.balanceOf(address(this));
    }

    ///////////////////////////////////////////// Internals

    /// How many vesting tokens an account is able to withdraw
    function _vestedByAccount(address account, uint256 _totalVested)
        internal
        view
        returns (uint256)
    {
        uint256 alreadyWithdrawn = withdrawn[account];
        uint256 accountClaim = wrappedByAccount(account);

        uint256 allVesting = allVestingEver();
        if (allVesting > 0) {
            uint256 totalVestedByAccount = (((accountClaim + alreadyWithdrawn) *
                _totalVested) / allVesting);
            if (totalVestedByAccount > alreadyWithdrawn) {
                return totalVestedByAccount - alreadyWithdrawn;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }

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
        if (amount > 0 && from != address(0)) {
            uint256 withdrawnFrom = withdrawn[from];
            uint256 balanceFrom = balanceOf(from);

            uint256 migrateAmount = (withdrawnFrom * amount) / balanceFrom;
            withdrawn[from] -= migrateAmount;
            withdrawn[to] += migrateAmount;
        }
    }
}
