// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./roles/RoleAware.sol";

abstract contract MintableToken is ReentrancyGuard, ERC20Permit, RoleAware {
    uint256 public globalSupplyCeiling;

    mapping(address => uint256) public minBalance;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 initialSupplyCeiling,
        address _roles
    ) RoleAware(_roles) ERC20(_name, _symbol) ERC20Permit(_symbol) {
        globalSupplyCeiling = initialSupplyCeiling;
    }

    // --------------------------- Mint / burn --------------------------------------//

    /// Mint stable, restricted to MinterBurner role (respecting global debt ceiling)
    function mint(address account, uint256 amount) external nonReentrant {
        require(
            isAuthorizedMinterBurner(msg.sender),
            "Not an autorized minter"
        );
        _mint(account, amount);

        require(
            globalSupplyCeiling > totalSupply(),
            "Total supply exceeds global debt ceiling"
        );
    }

    /// Burn stable, restricted to MinterBurner role
    function burn(address account, uint256 amount) external nonReentrant {
        require(
            isAuthorizedMinterBurner(msg.sender),
            "Not an authorized burner"
        );
        _burn(account, amount);
    }

    /// Set global supply ceiling
    function setGlobalSupplyCeiling(uint256 ceiling) external onlyOwnerExec {
        globalSupplyCeiling = ceiling;
    }

    // --------------------------- Min balances -------------------------------------//

    /// For some applications we may want to mint balances that can't be withdrawn or burnt.
    /// Contracts using this should first check balance before setting in a transaction
    function setMinBalance(address account, uint256 balance) external {
        require(
            isAuthorizedMinterBurner(msg.sender),
            "Not an authorized minter/burner"
        );

        minBalance[account] = balance;
    }

    /// Check transfer and burn transactions for minimum balance compliance
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._afterTokenTransfer(from, to, amount);
        require(
            balanceOf(from) >= minBalance[from],
            "MoreMoney: below min balance"
        );
    }

    /// Minting / burning access control
    function isAuthorizedMinterBurner(address caller)
        internal
        virtual
        returns (bool);
}
