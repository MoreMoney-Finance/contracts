// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./VeMoreToken.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../roles/RoleAware.sol";

contract VeMoreStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice events describing staking, unstaking and claiming
    event Staked(address indexed user, uint256 indexed amount);
    event Unstaked(address indexed user, uint256 indexed amount);
    event Claimed(address indexed user, uint256 indexed amount);

    IERC20 public more;
    VeMoreToken public veMore;

    struct UserInfo {
        uint256 amount; // more staked by user
        uint256 lastRelease; // time of last VeMore claim or first deposit if user has not claimed yet
    }

    /// @notice user info mapping
    mapping(address => UserInfo) public users;

    EnumerableSet.AddressSet private whitelist;

    /// @notice max VeMore to staked more ratio
    /// Note if user has 10 more staked, they can only have a max of 10 * maxCap VeMore in balance
    uint256 public maxCap = 100;

    /// @notice the rate of VeMore generated per second, per more staked
    uint256 public generationRate = 3888888888888;

    constructor() Ownable() {}

    /// @notice sets maxCap
    /// @param _maxCap the new max ratio
    function setMaxCap(uint256 _maxCap) external onlyOwner {
        require(_maxCap != 0, "max cap cannot be zero");
        maxCap = _maxCap;
    }

    /// @notice sets generation rate
    /// @param _generationRate the new max ratio
    function setGenerationRate(uint256 _generationRate) external onlyOwner {
        require(_generationRate != 0, "generation rate cannot be zero");
        generationRate = _generationRate;
    }

    /// @notice checks wether user _addr has more staked
    /// @param _addr the user address to check
    /// @return true if the user has more in stake, false otherwise
    function isUser(address _addr) public view returns (bool) {
        return users[_addr].amount > 0;
    }

    /// @notice returns staked amount of more for user
    /// @param _addr the user address to check
    /// @return staked amount ofmore
    function getStakedMore(address _addr) external view returns (uint256) {
        return users[_addr].amount;
    }

    /// @notice deposits more into contract
    /// @param _amount the amount of more to deposit
    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "amount to deposit cannot be zero");

        // assert call is not coming from a smart contract
        // unless it is whitelisted
        _assertNotContract(msg.sender);

        if (isUser(msg.sender)) {
            // if user exists, first, claim hisVeMore
            _claim(msg.sender);
            // then, increment his holdings
            users[msg.sender].amount += _amount;
        } else {
            // add new user to mapping
            users[msg.sender].lastRelease = block.timestamp;
            users[msg.sender].amount = _amount;
        }

        // Request more from user
        more.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /// @notice asserts addres in param is not a smart contract.
    /// @notice if it is a smart contract, check that it is whitelisted
    /// @param _addr the address to check
    function _assertNotContract(address _addr) private view {
        if (_addr != tx.origin) {
            require(
                whitelist.contains(_addr),
                "Smart contract depositors not allowed"
            );
        }
    }

    /// @notice claims accumulatedVeMore
    function claim() external nonReentrant {
        require(isUser(msg.sender), "user has no stake");
        _claim(msg.sender);
    }

    /// @dev private claim function
    /// @param _addr the address of the user to claim from
    function _claim(address _addr) private {
        uint256 amount = _claimable(_addr);

        // update last release time
        users[_addr].lastRelease = block.timestamp;

        if (amount > 0) {
            emit Claimed(_addr, amount);
            veMore.mint(_addr, amount);
        }
    }

    /// @notice Calculate the amount of VeMore that can be claimed by user
    /// @param _addr the address to check
    /// @return amount of VeMore that can be claimed by user
    function claimable(address _addr) external view returns (uint256) {
        require(_addr != address(0), "zero address");
        return _claimable(_addr);
    }

    /// @dev private claim function
    /// @param _addr the address of the user to claim from
    function _claimable(address _addr) private view returns (uint256) {
        UserInfo storage user = users[_addr];

        // get seconds elapsed since last claim
        uint256 secondsElapsed = block.timestamp - user.lastRelease;

        // calculate pending amount
        // Math.mwmul used to multiply wad numbers
        uint256 pending = wmul(user.amount, secondsElapsed * generationRate);

        // get user's VeMore balance
        uint256 userVeMoreBalance = veMore.balanceOf(_addr);

        // user VeMore balance cannot go above user.amount * maxCap
        uint256 maxVeMoreCap = user.amount * maxCap;

        // first, check that user hasn't reached the max limit yet
        if (userVeMoreBalance < maxVeMoreCap) {
            // then, check if pending amount will make user balance overpass maximum amount
            if ((userVeMoreBalance + pending) > maxVeMoreCap) {
                return maxVeMoreCap - userVeMoreBalance;
            } else {
                return pending;
            }
        }
        return 0;
    }

    /// @notice withdraws stakedmore
    /// @param _amount the amount of more to unstake
    /// Note Beware! you will loose all of your VeMore if you unstake any amount of more!
    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0, "amount to withdraw cannot be zero");
        require(users[msg.sender].amount >= _amount, "not enough balance");

        // reset last Release timestamp
        users[msg.sender].lastRelease = block.timestamp;

        // update his balance before burning or sending backmore
        users[msg.sender].amount -= _amount;

        // get user VeMore balance that must be burned
        uint256 userVeMoreBalance = veMore.balanceOf(msg.sender);

        veMore.burnFrom(msg.sender, userVeMoreBalance);

        // send back the stakedmore
        more.safeTransfer(msg.sender, _amount);
    }

    //rounds to zero if x*y < WAD / 2
    function wmul(uint256 x, uint256 y) internal pure returns (uint256) {
        return ((x * y) + (1e18 / 2)) / 1e18;
    }

    function viewWhitelist() external view returns (address[] memory) {
        return whitelist.values();
    }
}
