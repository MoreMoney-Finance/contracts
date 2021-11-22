// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IYakStrategy.sol";
import "./roles/RoleAware.sol";
import "./roles/DependsOnProtocolToken.sol";
import "./roles/DependsOnFeeRecipient.sol";

/// Prestake tokens for a fixed time
/// to distribute rewards in a time-amount-weighted manner
/// while aggregating yield to protocol
contract Prestaking is
    RoleAware,
    DependsOnProtocolToken,
    DependsOnFeeRecipient,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    IYakStrategy public immutable yieldContract;
    IERC20 public immutable stakingToken;

    uint256 public stakingEnd;

    struct StakingRecord {
        uint256 startTime;
        uint256 currentBalance;
        uint256 accumulatedWeight;
    }

    mapping(address => StakingRecord) public stakingRecords;

    uint256 public totalCurrentBalancesXstartTimes = 0;
    uint256 public totalAccumulatedWeights = 0;
    uint256 public totalCurrentBalances = 0;

    constructor(
        address _stakingToken,
        address _yieldContract,
        uint256 duration,
        address _roles
    ) RoleAware(_roles) {
        yieldContract = IYakStrategy(_yieldContract);
        stakingToken = IERC20(_stakingToken);

        stakingEnd = block.timestamp + duration;

        IERC20(_stakingToken).approve(_yieldContract, type(uint256).max);
    }

    /// Deposit stake
    function deposit(uint256 amount) external nonReentrant {
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        yieldContract.deposit(amount);

        StakingRecord storage stakingRecord = stakingRecords[msg.sender];

        _beforeBalanceUpdate(stakingRecord);
        stakingRecord.currentBalance += amount;
        _afterBalanceUpdate(stakingRecord);
    }

    /// Withdraw stake
    function withdraw(uint256 amount) external nonReentrant {
        uint256 shares = yieldContract.getSharesForDepositTokens(amount);

        uint256 balanceBefore = stakingToken.balanceOf(address(this));
        yieldContract.withdraw(shares);
        uint256 balanceAfter = stakingToken.balanceOf(address(this));

        StakingRecord storage stakingRecord = stakingRecords[msg.sender];

        _beforeBalanceUpdate(stakingRecord);
        stakingRecord.currentBalance -= amount;
        _afterBalanceUpdate(stakingRecord);

        stakingToken.safeTransfer(msg.sender, balanceAfter - balanceBefore);
    }

    /// Withdraw reward, if applicable
    function withdrawReward() external nonReentrant {
        require(block.timestamp >= stakingEnd, "Staking hasn't ended");
        require(
            protocolToken().balanceOf(address(this)) > 0,
            "Reward hasn't started"
        );

        StakingRecord storage stakingRecord = stakingRecords[msg.sender];

        // reset state, so stakingRecord.accumulatedWeight reflects final weight
        // and all other aggregates no longer include this stake
        _beforeBalanceUpdate(stakingRecord);

        uint256 reward = (protocolToken().balanceOf(address(this)) *
            stakingRecord.accumulatedWeight) / totalExpectedWeights();

        totalAccumulatedWeights -= stakingRecord.accumulatedWeight;
        stakingRecord.accumulatedWeight = 0;

        protocolToken().safeTransfer(msg.sender, reward);
    }

    /// accumulate weight and expunge tokenRecord from global tracking states
    function _beforeBalanceUpdate(StakingRecord storage stakingRecord)
        internal
    {
        if (stakingRecord.startTime > 0) {
            uint256 accumulatedWeight = stakingRecord.currentBalance *
                (mostRecent() - stakingRecord.startTime);
            stakingRecord.accumulatedWeight += accumulatedWeight;

            totalAccumulatedWeights += accumulatedWeight;
        }

        if (stakingEnd > stakingRecord.startTime) {
            totalCurrentBalancesXstartTimes -=
                stakingRecord.startTime *
                stakingRecord.currentBalance;
            totalCurrentBalances -= stakingRecord.currentBalance;
        }

        stakingRecord.startTime = mostRecent();
    }

    /// Write record back into global tracking states, if staking still ongoing
    function _afterBalanceUpdate(StakingRecord storage stakingRecord) internal {
        if (stakingEnd > block.timestamp) {
            totalCurrentBalancesXstartTimes +=
                stakingRecord.startTime *
                stakingRecord.currentBalance;
            totalCurrentBalances += stakingRecord.currentBalance;
        }
    }

    /// View expected reward per 10**18 (must be scaled up by reward amount)
    function viewExpectedRewardSharePer1e18(address staker)
        external
        view
        returns (uint256)
    {
        StakingRecord storage stakingRecord = stakingRecords[staker];

        return
            (1e18 *
                (stakingRecord.accumulatedWeight +
                    (stakingEnd - stakingRecord.startTime) *
                    stakingRecord.currentBalance)) / totalExpectedWeights();
    }

    /// Total weights at end of staking period if everyone currently staked would
    /// continue to stake (and no one else joined)
    /// sumAll(weights) = sumAll(balance_i * (endTime - startTime_i))
    /// = sumAll(balance_i) * endTime - sumAll(balance_i * startTime_i)
    function totalExpectedWeights() public view returns (uint256) {
        return
            totalAccumulatedWeights +
            totalCurrentBalances *
            stakingEnd -
            totalCurrentBalancesXstartTimes;
    }

    /// YY strategy share balance of this contract
    function totalShareBalance() public view returns (uint256) {
        return IERC20(address(yieldContract)).balanceOf(address(this));
    }

    /// Most recent staking timestamp, either staking end or currently
    function mostRecent() public view returns (uint256) {
        return min(block.timestamp, stakingEnd);
    }

    /// Minimum of two numbers
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return b;
        } else {
            return a;
        }
    }

    /// Withdraw yield for protocol to fee recipient
    function withdrawProtocolYield()
        external
        onlyOwnerExecDisabler
        nonReentrant
    {
        uint256 yieldInShares = totalShareBalance() -
            yieldContract.getSharesForDepositTokens(totalCurrentBalances);
        yieldContract.withdraw(yieldInShares);
        stakingToken.safeTransfer(
            feeRecipient(),
            stakingToken.balanceOf(address(this))
        );
    }

    /// In an emergency, withdraw any tokens stranded in this contract's balance
    function rescueStrandedTokens(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwnerExec nonReentrant {
        require(recipient != address(0), "Don't send to zero address");
        IERC20(token).safeTransfer(recipient, amount);
    }

    /// Rescue any stranded native currency
    function rescueNative(uint256 amount, address recipient)
        external
        nonReentrant
        onlyOwnerExec
    {
        require(recipient != address(0), "Don't send to zero address");
        payable(recipient).transfer(amount);
    }

    /// Change staking end
    function setStakingEnd(uint256 end) external onlyOwnerExecDisabler {
        stakingEnd = end;
    }
}
