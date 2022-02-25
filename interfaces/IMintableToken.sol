// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMintableToken is IERC20 {
    /// Mint tokens
    function mint(address account, uint256 amount) external;

    /// Burn tokens
    function burn(address account, uint256 amount) external;

    /// For some applications we may want to mint balances that can't be withdrawn or burnt.
    /// Contracts using this should first check balance before setting in a transaction
    function setMinBalance(address account, uint256 balance) external;

    /// Set global supply ceiling
    function setGlobalSupplyCeiling(uint256 ceiling) external;

    /// Min balance
    function minBalance(address account) external view returns (uint256);
}
