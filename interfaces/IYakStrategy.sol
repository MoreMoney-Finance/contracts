// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IYakStrategy {

    function depositToken() external returns(IERC20);

    /**
     * @notice Deposit and deploy deposits tokens to the strategy
     * @dev Must mint receipt tokens to `msg.sender`
     * @param amount deposit tokens
     */
    function deposit(uint amount) external;

    /**
    * @notice Deposit using Permit
    * @dev Should revert for tokens without Permit
    * @param amount Amount of tokens to deposit
    * @param deadline The time at which to expire the signature
    * @param v The recovery byte of the signature
    * @param r Half of the ECDSA signature pair
    * @param s Half of the ECDSA signature pair
    */
    function depositWithPermit(uint amount, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * @notice Deposit on behalf of another account
     * @dev Must mint receipt tokens to `account`
     * @param account address to receive receipt tokens
     * @param amount deposit tokens
     */
    function depositFor(address account, uint amount) external;

    /**
     * @notice Redeem receipt tokens for deposit tokens
     * @param amount receipt tokens
     */
    function withdraw(uint amount) external;

    /**
     * @notice Reinvest reward tokens into deposit tokens
     */
    function reinvest() external;

    /**
     * @notice Estimate reinvest reward
     * @return reward tokens
     */
    function estimateReinvestReward() external view returns (uint);

    /**
     * @notice Reward tokens avialable to strategy, including balance
     * @return reward tokens
     */
    function checkReward() external view returns (uint);

    /**
     * @notice Estimated deposit token balance deployed by strategy, excluding balance
     * @return deposit tokens
     */
    function estimateDeployedBalance() external view returns (uint);

    /**
     * @notice Rescue all available deployed deposit tokens back to Strategy
     * @param minReturnAmountAccepted min deposit tokens to receive
     * @param disableDeposits bool
     */
    function rescueDeployedFunds(uint minReturnAmountAccepted, bool disableDeposits) external;

    /**
     * @notice Calculate receipt tokens for a given amount of deposit tokens
     * @dev If contract is empty, use 1:1 ratio
     * @dev Could return zero shares for very low amounts of deposit tokens
     * @param amount deposit tokens
     * @return receipt tokens
     */
    function getSharesForDepositTokens(uint amount) external view returns (uint);

    /**
     * @notice Calculate deposit tokens for a given amount of receipt tokens
     * @param amount receipt tokens
     * @return deposit tokens
     */
    function getDepositTokensForShares(uint amount) external view returns (uint);
}