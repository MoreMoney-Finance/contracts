pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";

import "../roles/RoleAware.sol";
import "../roles/DependsOnStableCoin.sol";
import "../oracles/OracleAware.sol";

// https://docs.synthetix.io/contracts/source/contracts/stakingrewards
abstract contract VestingStakingRewards is
    ReentrancyGuard,
    RoleAware,
    OracleAware,
    DependsOnStableCoin
{
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public immutable rewardsToken;
    IERC20 public immutable stakingToken;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 60 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public vestingPeriod;
    uint256 public instantVestingPer10k = (10_000 * 10) / 100;
    uint256 public vestingCliff;

    mapping(address => uint256) public userRewardPerTokenAccountedFor;
    mapping(address => uint256) public vestingStart;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    constructor(address _rewardsToken, address _stakingToken, uint256 _vestingCliff, uint256 _vestingPeriod) {
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
        vestingCliff = _vestingCliff;
        vestingPeriod = _vestingPeriod;
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function totalValueLocked() public view returns (uint256) {
        if (_totalSupply == 0) {
            return 0;
        } else {
            return
                _viewValue(
                    address(stakingToken),
                    _totalSupply,
                    address(stableCoin())
                );
        }
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) *
                rewardRate *
                1e18) /
            _totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        return
            (_balances[account] *
                (rewardPerToken() - userRewardPerTokenAccountedFor[account])) /
            1e18;
    }

    function vested(address account) public view returns (uint256) {
        uint256 vStart = vestingStart[account];
        if (
            vStart == 0 ||
            vStart > block.timestamp ||
            vestingCliff > block.timestamp
        ) {
            return 0;
        } else {
            uint256 timeDelta = block.timestamp - vStart;
            uint256 totalRewards = rewards[account];
            if (vestingPeriod == 0) {
                return totalRewards;
            } else {
                uint256 earnedAmount = earned(account);
                uint256 instantlyVested = (instantVestingPer10k *
                    earnedAmount) / 10_000;
                uint256 rewardVested = vStart > 0 && timeDelta > 0
                    ? min(
                        totalRewards,
                        (totalRewards * timeDelta) / vestingPeriod
                    )
                    : 0;
                return rewardVested + instantlyVested;
            }
        }
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    function viewAPRPer10k() public view returns (uint256) {
        if (rewardRate == 0) {
            return 0;
        } else if (_totalSupply == 0) {
            return (30 * 10_000) / 100;
        } else {
            return
                _viewValue(
                    address(rewardsToken),
                    10_000 * rewardRate * (365 days),
                    address(stableCoin())
                ) /
                _viewValue(
                    address(stakingToken),
                    _totalSupply,
                    address(stableCoin())
                );
        }
    }

    struct StakingMetadata {
        address stakingToken;
        address rewardsToken;
        uint256 totalSupply;
        uint256 tvl;
        uint256 aprPer10k;
        uint256 vestingCliff;
        uint256 periodFinish;
        uint256 stakedBalance;
        uint256 vestingStart;
        uint256 earned;
        uint256 rewards;
        uint256 vested;
    }

    function stakingMetadata(address account)
        external
        view
        returns (StakingMetadata memory)
    {
        return
            StakingMetadata({
                stakingToken: address(stakingToken),
                rewardsToken: address(rewardsToken),
                totalSupply: _totalSupply,
                tvl: totalValueLocked(),
                aprPer10k: viewAPRPer10k(),
                vestingCliff: vestingCliff,
                periodFinish: periodFinish,
                stakedBalance: _balances[account],
                vestingStart: vestingStart[account],
                earned: earned(account),
                rewards: rewards[account],
                vested: vested(account)
            });
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stakeWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply + amount;
        _balances[msg.sender] = _balances[msg.sender] + amount;

        // permit
        IERC20Permit(address(stakingToken)).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function stake(uint256 amount)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply + amount;
        _balances[msg.sender] = _balances[msg.sender] + amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount)
        public
        nonReentrant
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply = _totalSupply - amount;
        _balances[msg.sender] = _balances[msg.sender] - amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    // This relies on updateReward to disburse the vested reward
    function withdrawVestedReward()
        public
        nonReentrant
        updateReward(msg.sender)
    {}

    function exit() external {
        withdraw(_balances[msg.sender]);
        // getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // Always needs to update the balance of the contract when calling this method
    function notifyRewardAmount(uint256 reward)
        external
        onlyOwnerExec
        updateReward(address(0))
    {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = rewardsToken.balanceOf(address(this));
        require(
            rewardRate <= balance / rewardsDuration,
            "Provided reward too high"
        );

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
        emit RewardAdded(reward);
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        external
        onlyOwnerExec
        nonReentrant
    {
        require(
            tokenAddress != address(stakingToken),
            "Cannot withdraw the staking token"
        );
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setRewardsDuration(uint256 _rewardsDuration)
        external
        onlyOwnerExec
    {
        require(
            block.timestamp > periodFinish,
            "Previous rewards period must be complete before changing the duration for the new period"
        );
        require(_rewardsDuration > 0, "Reward duration can't be zero");
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    function setVestingPeriod(uint256 period) external onlyOwnerExec {
        vestingPeriod = period;
    }

    function setInstantVestingPer10k(uint256 vestingPer10k)
        external
        onlyOwnerExec
    {
        require(10_000 >= vestingPer10k, "Must be smaller than 10k");
        instantVestingPer10k = vestingPer10k;
    }

    function setVestingCliff(uint256 _vestingCliff) external onlyOwnerExec {
        vestingCliff = _vestingCliff;
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            uint256 earnedAmount = earned(account);
            rewards[account] += earnedAmount;
            userRewardPerTokenAccountedFor[account] = rewardPerTokenStored;

            uint256 vestedAmount = vested(account);
            if (vestedAmount > 0) {
                rewardsToken.safeTransfer(account, vestedAmount);
                rewards[account] -= vestedAmount;

                emit RewardPaid(account, vestedAmount);
            }
            vestingStart[account] = max(vestingCliff, block.timestamp);
        }

        address stable = address(stableCoin());
        // update oracles for APR calculation
        _getValue(address(rewardsToken), 1e18, stable);
        _getValue(address(stakingToken), 1e18, stable);
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a >= b) {
            return b;
        } else {
            return a;
        }
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a >= b) {
            return a;
        } else {
            return b;
        }
    }
}
