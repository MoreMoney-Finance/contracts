// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./Math.sol";
import "./SafeOwnableUpgradeable.sol";
import "../../interfaces/IVeMore.sol";
import "../../interfaces/IMasterMore.sol";
import "../../interfaces/IRewarder.sol";

/// MasterMore is a boss. He says "go f your blocks maki boy, I'm gonna use timestamp instead"
/// In addition, veMore holders boost their (non-diluting) emissions.
/// This contract rewards users in function of their amount of lp staked (diluting pool) factor (non-diluting pool)
/// Factor and sumOfFactors are updated by contract VeMore.sol after any veMore minting/burning (veERC20Upgradeable hook).
/// Note that it's ownable and the owner wields tremendous power. The ownership
/// will be transferred to a governance smart contract once More is sufficiently
/// distributed and the community can show to govern itself.
contract MasterMore is
    Initializable,
    SafeOwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IMasterMore
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 factor; // non-diluting factor = sqrt (lpAmount * veMore.balanceOf())
        //
        // We do some fancy math here. Basically, any point in time, the amount of MOREs
        // entitled to a user but is pending to be distributed is:
        //
        //   ((user.amount * pool.accMorePerShare + user.factor * pool.accMorePerFactorShare) / 1e12) -
        //        user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accMorePerShare`, `accMorePerFactorShare` (and `lastRewardTimestamp`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many base allocation points assigned to this pool
        uint256 lastRewardTimestamp; // Last timestamp that MOREs distribution occurs.
        uint256 accMorePerShare; // Accumulated MOREs per share, times 1e12.
        IRewarder rewarder;
        uint256 sumOfFactors; // the sum of all non diluting factors by all of the users in the pool
        uint256 accMorePerFactorShare; // accumulated more per factor share
        // Note : beware storage collision with old MasterMore
    }

    // The strongest more out there (more token).
    IERC20 public more;
    // Venom does not seem to hurt the More, it only makes it stronger.
    IVeMore public veMore;
    // New Master More address for future migrations
    IMasterMore public newMasterMore;
    // MORE tokens created per second.
    uint256 public morePerSec;
    // Emissions: both must add to 1000 => 100%
    // Diluting emissions repartition (e.g. 300 for 30%)
    uint256 public dilutingRepartition;
    // Non-diluting emissions repartition (e.g. 500 for 50%)
    uint256 public nonDilutingRepartition;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The timestamp when MORE mining starts.
    uint256 public startTimestamp;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Set of all LP tokens that have been added as pools
    EnumerableSet.AddressSet private lpTokens;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Amount of claimable more the user has
    mapping(uint256 => mapping(address => uint256)) public claimableMore;
    // The maximum number of pools, in case updateFactor() exceeds block gas limit
    uint256 public maxPoolLength;

    event Add(
        uint256 indexed pid,
        uint256 allocPoint,
        IERC20 indexed lpToken,
        IRewarder indexed rewarder
    );
    event Set(
        uint256 indexed pid,
        uint256 allocPoint,
        IRewarder indexed rewarder,
        bool overwrite
    );
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event DepositFor(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event UpdatePool(
        uint256 indexed pid,
        uint256 lastRewardTimestamp,
        uint256 lpSupply,
        uint256 accMorePerShare
    );
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event UpdateEmissionRate(address indexed user, uint256 morePerSec);
    event UpdateEmissionRepartition(
        address indexed user,
        uint256 dilutingRepartition,
        uint256 nonDilutingRepartition
    );
    event UpdateVeMORE(
        address indexed user,
        address oldVeMORE,
        address newVeMORE
    );

    /// @dev Modifier ensuring that certain function can only be called by VeMore
    modifier onlyVeMore() {
        require(address(veMore) == msg.sender, "notVeMore: wut?");
        _;
    }

    function initialize(
        IERC20 _more,
        IVeMore _veMore,
        uint256 _morePerSec,
        uint256 _dilutingRepartition,
        uint256 _startTimestamp
    ) public initializer {
        require(address(_more) != address(0), "more address cannot be zero");
        require(
            address(_veMore) != address(0),
            "veMore address cannot be zero"
        );
        require(_morePerSec != 0, "more per sec cannot be zero");
        require(
            _dilutingRepartition <= 1000,
            "diluting repartition must be in range 0, 1000"
        );

        __Ownable_init();
        __ReentrancyGuard_init_unchained();
        __Pausable_init_unchained();

        more = _more;
        veMore = _veMore;
        morePerSec = _morePerSec;
        dilutingRepartition = _dilutingRepartition;
        nonDilutingRepartition = 1000 - _dilutingRepartition;
        startTimestamp = _startTimestamp;
        maxPoolLength = 50;
    }

    /**
     * @dev pause pool, restricting certain operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev unpause pool, enabling certain operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function setNewMasterMore(IMasterMore _newMasterMore) external onlyOwner {
        newMasterMore = _newMasterMore;
    }

    function setMaxPoolLength(uint256 _maxPoolLength) external onlyOwner {
        require(poolInfo.length <= _maxPoolLength);
        maxPoolLength = _maxPoolLength;
    }

    /// @notice returns pool length
    function poolLength() external view override returns (uint256) {
        return poolInfo.length;
    }

    /// @notice Add a new lp to the pool. Can only be called by the owner.
    /// @dev Reverts if the same LP token is added more than once.
    /// @param _allocPoint allocation points for this LP
    /// @param _lpToken the corresponding lp token
    /// @param _rewarder the rewarder
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        IRewarder _rewarder
    ) public onlyOwner {
        require(
            Address.isContract(address(_lpToken)),
            "add: LP token must be a valid contract"
        );
        require(
            Address.isContract(address(_rewarder)) ||
                address(_rewarder) == address(0),
            "add: rewarder must be contract or zero"
        );
        require(!lpTokens.contains(address(_lpToken)), "add: LP already added");
        require(poolInfo.length < maxPoolLength, "add: exceed max pool");

        // update all pools
        massUpdatePools();

        // update last time rewards were calculated to now
        uint256 lastRewardTimestamp = block.timestamp > startTimestamp
            ? block.timestamp
            : startTimestamp;

        // update alloc point
        totalAllocPoint += _allocPoint;

        // update PoolInfo with the new LP
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardTimestamp: lastRewardTimestamp,
                accMorePerShare: 0,
                rewarder: _rewarder,
                sumOfFactors: 0,
                accMorePerFactorShare: 0
            })
        );

        // add lpToken to the lpTokens enumerable set
        lpTokens.add(address(_lpToken));
        emit Add(poolInfo.length - 1, _allocPoint, _lpToken, _rewarder);
    }

    /// @notice Update the given pool's MORE allocation point. Can only be called by the owner.
    /// @param _pid the pool id
    /// @param _allocPoint allocation points
    /// @param _rewarder the rewarder
    /// @param overwrite overwrite rewarder?
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        IRewarder _rewarder,
        bool overwrite
    ) public onlyOwner {
        require(
            Address.isContract(address(_rewarder)) ||
                address(_rewarder) == address(0),
            "set: rewarder must be contract or zero"
        );
        massUpdatePools();

        PoolInfo storage pool = poolInfo[_pid];

        totalAllocPoint = totalAllocPoint - pool.allocPoint + _allocPoint;
        pool.allocPoint = _allocPoint;

        if (overwrite) {
            pool.rewarder = _rewarder;
        }
        emit Set(
            _pid,
            _allocPoint,
            overwrite ? _rewarder : pool.rewarder,
            overwrite
        );
    }

    /// @notice View function to see pending MOREs on frontend.
    /// @param _pid the pool id
    /// @param _user the user address
    /// TODO include factor operations
    function pendingTokens(uint256 _pid, address _user)
        external
        view
        override
        returns (
            uint256 pendingMore,
            address bonusTokenAddress,
            string memory bonusTokenSymbol,
            uint256 pendingBonusToken
        )
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accMorePerShare = pool.accMorePerShare;
        uint256 accMorePerFactorShare = pool.accMorePerFactorShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 secondsElapsed = block.timestamp - pool.lastRewardTimestamp;
            uint256 moreReward = (secondsElapsed *
                morePerSec *
                pool.allocPoint) / totalAllocPoint;
            accMorePerShare +=
                (moreReward * 1e12 * dilutingRepartition) /
                (lpSupply * 1000);
            if (pool.sumOfFactors != 0) {
                accMorePerFactorShare +=
                    (moreReward * 1e12 * nonDilutingRepartition) /
                    (pool.sumOfFactors * 1000);
            }
        }
        pendingMore =
            ((user.amount *
                accMorePerShare +
                user.factor *
                accMorePerFactorShare) / 1e12) +
            claimableMore[_pid][_user] -
            user.rewardDebt;
        // If it's a double reward farm, we return info about the bonus token
        if (address(pool.rewarder) != address(0)) {
            (bonusTokenAddress, bonusTokenSymbol) = rewarderBonusTokenInfo(
                _pid
            );
            pendingBonusToken = pool.rewarder.pendingTokens(_user);
        }
    }

    /// @notice Get bonus token info from the rewarder contract for a given pool, if it is a double reward farm
    /// @param _pid the pool id
    function rewarderBonusTokenInfo(uint256 _pid)
        public
        view
        override
        returns (address bonusTokenAddress, string memory bonusTokenSymbol)
    {
        PoolInfo storage pool = poolInfo[_pid];
        if (address(pool.rewarder) != address(0)) {
            bonusTokenAddress = address(pool.rewarder.rewardToken());
            bonusTokenSymbol = IERC20Metadata(pool.rewarder.rewardToken())
                .symbol();
        }
    }

    /// @notice Update reward variables for all pools.
    /// @dev Be careful of gas spending!
    function massUpdatePools() public override {
        uint256 length = poolInfo.length;
        for (uint256 pid; pid < length; ++pid) {
            _updatePool(pid);
        }
    }

    /// @notice Update reward variables of the given pool to be up-to-date.
    /// @param _pid the pool id
    function updatePool(uint256 _pid) external override {
        _updatePool(_pid);
    }

    function _updatePool(uint256 _pid) private {
        PoolInfo storage pool = poolInfo[_pid];
        // update only if now > last time we updated rewards
        if (block.timestamp > pool.lastRewardTimestamp) {
            uint256 lpSupply = pool.lpToken.balanceOf(address(this));

            // if balance of lp supply is 0, update lastRewardTime and quit function
            if (lpSupply == 0) {
                pool.lastRewardTimestamp = block.timestamp;
                return;
            }
            // calculate seconds elapsed since last update
            uint256 secondsElapsed = block.timestamp - pool.lastRewardTimestamp;

            // calculate more reward
            uint256 moreReward = (secondsElapsed *
                morePerSec *
                pool.allocPoint) / totalAllocPoint;
            // update accMorePerShare to reflect diluting rewards
            pool.accMorePerShare +=
                (moreReward * 1e12 * dilutingRepartition) /
                (lpSupply * 1000);

            // update accMorePerFactorShare to reflect non-diluting rewards
            if (pool.sumOfFactors == 0) {
                pool.accMorePerFactorShare = 0;
            } else {
                pool.accMorePerFactorShare +=
                    (moreReward * 1e12 * nonDilutingRepartition) /
                    (pool.sumOfFactors * 1000);
            }

            // update lastRewardTimestamp to now
            pool.lastRewardTimestamp = block.timestamp;
            emit UpdatePool(
                _pid,
                pool.lastRewardTimestamp,
                lpSupply,
                pool.accMorePerShare
            );
        }
    }

    /// @notice Helper function to migrate fund from multiple pools to the new MasterMore.
    /// @notice user must initiate transaction from masterchef
    /// @dev Assume the orginal MasterMore has stopped emisions
    /// hence we can skip updatePool() to save gas cost
    function migrate(uint256[] calldata _pids) external override nonReentrant {
        require(address(newMasterMore) != (address(0)), "to where?");

        _multiClaim(_pids);
        for (uint256 i; i < _pids.length; ++i) {
            uint256 pid = _pids[i];
            UserInfo storage user = userInfo[pid][msg.sender];

            if (user.amount > 0) {
                PoolInfo storage pool = poolInfo[pid];
                pool.lpToken.approve(address(newMasterMore), user.amount);
                newMasterMore.depositFor(pid, user.amount, msg.sender);

                pool.sumOfFactors -= user.factor;
                delete userInfo[pid][msg.sender];
            }
        }
    }

    /// @notice Deposit LP tokens to MasterChef for MORE allocation on behalf of user
    /// @dev user must initiate transaction from masterchef
    /// @param _pid the pool id
    /// @param _amount amount to deposit
    /// @param _user the user being represented
    function depositFor(
        uint256 _pid,
        uint256 _amount,
        address _user
    ) external override nonReentrant whenNotPaused {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        // update pool in case user has deposited
        _updatePool(_pid);
        if (user.amount > 0) {
            // Harvest MORE
            uint256 pending = ((user.amount *
                pool.accMorePerShare +
                user.factor *
                pool.accMorePerFactorShare) / 1e12) +
                claimableMore[_pid][_user] -
                user.rewardDebt;
            claimableMore[_pid][_user] = 0;

            pending = safeMoreTransfer(payable(_user), pending);
            emit Harvest(_user, _pid, pending);
        }

        // update amount of lp staked by user
        user.amount += _amount;

        // update non-diluting factor
        uint256 oldFactor = user.factor;
        user.factor = Math.sqrt(user.amount * veMore.balanceOf(_user));
        pool.sumOfFactors = pool.sumOfFactors + user.factor - oldFactor;

        // update reward debt
        user.rewardDebt =
            (user.amount *
                pool.accMorePerShare +
                user.factor *
                pool.accMorePerFactorShare) /
            1e12;

        IRewarder rewarder = poolInfo[_pid].rewarder;
        if (address(rewarder) != address(0)) {
            rewarder.onMoreReward(_user, user.amount);
        }

        pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit DepositFor(_user, _pid, _amount);
    }

    /// @notice Deposit LP tokens to MasterChef for MORE allocation.
    /// @dev it is possible to call this function with _amount == 0 to claim current rewards
    /// @param _pid the pool id
    /// @param _amount amount to deposit
    function deposit(uint256 _pid, uint256 _amount)
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256, uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        _updatePool(_pid);
        uint256 pending;

        if (user.amount > 0) {
            // Harvest MORE
            pending =
                ((user.amount *
                    pool.accMorePerShare +
                    user.factor *
                    pool.accMorePerFactorShare) / 1e12) +
                claimableMore[_pid][msg.sender] -
                user.rewardDebt;
            claimableMore[_pid][msg.sender] = 0;

            pending = safeMoreTransfer(payable(msg.sender), pending);
            emit Harvest(msg.sender, _pid, pending);
        }

        // update amount of lp staked by user
        user.amount += _amount;

        // update non-diluting factor
        uint256 oldFactor = user.factor;
        user.factor = Math.sqrt(user.amount * veMore.balanceOf(msg.sender));
        pool.sumOfFactors = pool.sumOfFactors + user.factor - oldFactor;

        // update reward debt
        user.rewardDebt =
            (user.amount *
                pool.accMorePerShare +
                user.factor *
                pool.accMorePerFactorShare) /
            1e12;

        IRewarder rewarder = poolInfo[_pid].rewarder;
        uint256 additionalRewards;
        if (address(rewarder) != address(0)) {
            additionalRewards = rewarder.onMoreReward(msg.sender, user.amount);
        }

        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );

        emit Deposit(msg.sender, _pid, _amount);
        return (pending, additionalRewards);
    }

    /// @notice claims rewards for multiple pids
    /// @param _pids array pids, pools to claim
    function multiClaim(uint256[] memory _pids)
        external
        override
        nonReentrant
        whenNotPaused
        returns (
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        return _multiClaim(_pids);
    }

    /// @notice private function to claim rewards for multiple pids
    /// @param _pids array pids, pools to claim
    function _multiClaim(uint256[] memory _pids)
        private
        returns (
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        // accumulate rewards for each one of the pids in pending
        uint256 pending;
        uint256[] memory amounts = new uint256[](_pids.length);
        uint256[] memory additionalRewards = new uint256[](_pids.length);
        for (uint256 i; i < _pids.length; ++i) {
            _updatePool(_pids[i]);
            PoolInfo storage pool = poolInfo[_pids[i]];
            UserInfo storage user = userInfo[_pids[i]][msg.sender];
            if (user.amount > 0) {
                // increase pending to send all rewards once
                uint256 poolRewards = ((user.amount *
                    pool.accMorePerShare +
                    user.factor *
                    pool.accMorePerFactorShare) / 1e12) +
                    claimableMore[_pids[i]][msg.sender] -
                    user.rewardDebt;

                claimableMore[_pids[i]][msg.sender] = 0;

                // update reward debt
                user.rewardDebt =
                    (user.amount *
                        pool.accMorePerShare +
                        user.factor *
                        pool.accMorePerFactorShare) /
                    1e12;

                // increase pending
                pending += poolRewards;

                amounts[i] = poolRewards;
                // if existant, get external rewarder rewards for pool
                IRewarder rewarder = pool.rewarder;
                if (address(rewarder) != address(0)) {
                    additionalRewards[i] = rewarder.onMoreReward(
                        msg.sender,
                        user.amount
                    );
                }
            }
        }
        // transfer all remaining rewards
        uint256 transfered = safeMoreTransfer(payable(msg.sender), pending);
        if (transfered != pending) {
            for (uint256 i; i < _pids.length; ++i) {
                amounts[i] = (transfered * amounts[i]) / pending;
                emit Harvest(msg.sender, _pids[i], amounts[i]);
            }
        } else {
            for (uint256 i; i < _pids.length; ++i) {
                // emit event for pool
                emit Harvest(msg.sender, _pids[i], amounts[i]);
            }
        }

        return (transfered, amounts, additionalRewards);
    }

    /// @notice Withdraw LP tokens from MasterMore.
    /// @notice Automatically harvest pending rewards and sends to user
    /// @param _pid the pool id
    /// @param _amount the amount to withdraw
    function withdraw(uint256 _pid, uint256 _amount)
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256, uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        _updatePool(_pid);

        // Harvest MORE
        uint256 pending = ((user.amount *
            pool.accMorePerShare +
            user.factor *
            pool.accMorePerFactorShare) / 1e12) +
            claimableMore[_pid][msg.sender] -
            user.rewardDebt;
        claimableMore[_pid][msg.sender] = 0;

        pending = safeMoreTransfer(payable(msg.sender), pending);
        emit Harvest(msg.sender, _pid, pending);

        // for non-diluting factor
        uint256 oldFactor = user.factor;

        // update amount of lp staked
        user.amount = user.amount - _amount;

        // update non-diluting factor
        user.factor = Math.sqrt(user.amount * veMore.balanceOf(msg.sender));
        pool.sumOfFactors = pool.sumOfFactors + user.factor - oldFactor;

        // update reward debt
        user.rewardDebt =
            (user.amount *
                pool.accMorePerShare +
                user.factor *
                pool.accMorePerFactorShare) /
            1e12;

        IRewarder rewarder = poolInfo[_pid].rewarder;
        uint256 additionalRewards;
        if (address(rewarder) != address(0)) {
            additionalRewards = rewarder.onMoreReward(msg.sender, user.amount);
        }

        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
        return (pending, additionalRewards);
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param _pid the pool id
    function emergencyWithdraw(uint256 _pid) public override nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);

        // update non-diluting factor
        pool.sumOfFactors = pool.sumOfFactors - user.factor;
        user.factor = 0;

        // update diluting factors
        user.amount = 0;
        user.rewardDebt = 0;

        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }

    /// @notice Safe more transfer function, just in case if rounding error causes pool to not have enough MOREs.
    /// @param _to beneficiary
    /// @param _amount the amount to transfer
    function safeMoreTransfer(address payable _to, uint256 _amount)
        private
        returns (uint256)
    {
        uint256 moreBal = more.balanceOf(address(this));

        // perform additional check in case there are no more more tokens to distribute.
        // emergency withdraw would be necessary
        require(moreBal > 0, "No tokens to distribute");

        if (_amount > moreBal) {
            more.transfer(_to, moreBal);
            return moreBal;
        } else {
            more.transfer(_to, _amount);
            return _amount;
        }
    }

    /// @notice updates emission rate
    /// @param _morePerSec more amount to be updated
    /// @dev Pancake has to add hidden dummy pools inorder to alter the emission,
    /// @dev here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _morePerSec) external onlyOwner {
        massUpdatePools();
        morePerSec = _morePerSec;
        emit UpdateEmissionRate(msg.sender, _morePerSec);
    }

    /// @notice updates emission repartition
    /// @param _dilutingRepartition the future diluting repartition
    function updateEmissionRepartition(uint256 _dilutingRepartition)
        external
        onlyOwner
    {
        require(_dilutingRepartition <= 1000);
        massUpdatePools();
        dilutingRepartition = _dilutingRepartition;
        nonDilutingRepartition = 1000 - _dilutingRepartition;
        emit UpdateEmissionRepartition(
            msg.sender,
            _dilutingRepartition,
            1000 - _dilutingRepartition
        );
    }

    /// @notice updates veMore address
    /// @param _newVeMore the new VeMore address
    function setVeMore(IVeMore _newVeMore) external onlyOwner {
        require(address(_newVeMore) != address(0));
        massUpdatePools();
        IVeMore oldVeMore = veMore;
        veMore = _newVeMore;
        emit UpdateVeMORE(msg.sender, address(oldVeMore), address(_newVeMore));
    }

    /// @notice updates factor after any veMore token operation (minting/burning)
    /// @param _user the user to update
    /// @param _newVeMoreBalance the amount of veMORE
    /// @dev can only be called by veMore
    function updateFactor(address _user, uint256 _newVeMoreBalance)
        external
        override
        onlyVeMore
    {
        // loop over each pool : beware gas cost!
        uint256 length = poolInfo.length;

        for (uint256 pid = 0; pid < length; ++pid) {
            UserInfo storage user = userInfo[pid][_user];

            // skip if user doesn't have any deposit in the pool
            if (user.amount == 0) {
                continue;
            }

            PoolInfo storage pool = poolInfo[pid];

            // first, update pool
            _updatePool(pid);
            // calculate pending
            uint256 pending = ((user.amount *
                pool.accMorePerShare +
                user.factor *
                pool.accMorePerFactorShare) / 1e12) - user.rewardDebt;
            // increase claimableMore
            claimableMore[pid][_user] += pending;
            // get oldFactor
            uint256 oldFactor = user.factor; // get old factor
            // calculate newFactor using
            uint256 newFactor = Math.sqrt(_newVeMoreBalance * user.amount);
            // update user factor
            user.factor = newFactor;
            // update reward debt, take into account newFactor
            user.rewardDebt =
                (user.amount *
                    pool.accMorePerShare +
                    newFactor *
                    pool.accMorePerFactorShare) /
                1e12;
            // also, update sumOfFactors
            pool.sumOfFactors = pool.sumOfFactors + newFactor - oldFactor;
        }
    }

    /// @notice In case we need to manually migrate MORE funds from MasterChef
    /// Sends all remaining more from the contract to the owner
    function emergencyMoreWithdraw() external onlyOwner {
        more.safeTransfer(address(msg.sender), more.balanceOf(address(this)));
    }
}
