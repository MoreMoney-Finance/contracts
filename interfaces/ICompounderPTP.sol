pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICompounderPTP {
    function DELAY_BETWEEN_COMPOUNDS() external view returns (uint256);

    function DENOMINATOR() external view returns (uint256);

    function PTP() external view returns (address);

    function WAVAX() external view returns (address);

    function addRewardToken(address rewardToken) external;

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function aprHelper() external view returns (address);

    function assetToken() external view returns (address);

    function avaxHelper() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function callerFee() external view returns (uint256);

    function compound() external;

    function convertDust() external;

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool);

    function deleteRewardToken(uint256 index) external;

    function deposit(uint256 amount) external;

    function depositAvax() external;

    function depositToken() external view returns (address);

    function depositTracking(address) external view returns (uint256);

    function getDepositTokensForShares(uint256 amount)
        external
        view
        returns (uint256);

    function getRewardLength() external view returns (uint256 length);

    function getSharesForDepositTokens(uint256 amount)
        external
        view
        returns (uint256);

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool);

    function isRewardToken(address) external view returns (bool);

    function lastCompoundTime() external view returns (uint256);

    function lvtxFee() external view returns (uint256);

    function lvtxRewarder() external view returns (address);

    function mainStaking() external view returns (address);

    function maxRewardPending() external view returns (uint256);

    function migrateAllUserDepositsFromManual() external;

    function migrateAllUserDepositsToManual() external;

    function migrateFromManual(uint256 amount) external;

    function migrateToManual(uint256 amount) external;

    function owner() external view returns (address);

    function poolHelper() external view returns (address);

    function previewAvaxAmountForHarvest()
        external
        view
        returns (uint256 avaxAmount);

    function protocolFee() external view returns (uint256);

    function protocolFeeRecipient() external view returns (address);

    function renounceOwnership() external;

    function rewardTokens(uint256) external view returns (address);

    function setAPRHelper(address _aprHelper) external;

    function setAvaxHelper(address _avaxHelper) external;

    function setCallerFee(uint256 newValue) external;

    function setLvtxFee(uint256 newValue) external;

    function setLvtxRewarder(address _rewarder) external;

    function setMaximumPendingReward(uint256 _maxRewardPending) external;

    function setProtocolFee(uint256 newValue) external;

    function setProtocolFeeRecipient(address _recipient) external;

    function setSwapHelper(address _swapHelper) external;

    function stakingToken() external view returns (address);

    function swapHelper() external view returns (address);

    function totalDeposits() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferOwnership(address newOwner) external;

    function updatePoolHelper() external;

    function userDepositToken(address user)
        external
        view
        returns (uint256 userDeposit);

    function userInitialDepositToken(address user)
        external
        view
        returns (uint256 userInitialDeposit);

    function withdraw(uint256 amount, uint256 minAmount) external;

    function withdrawAvax(uint256 amount, uint256 minAmount) external;
}
