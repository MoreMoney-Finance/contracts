// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./roles/RoleAware.sol";
import "./roles/DependsOnMinterBurner.sol";
import "./roles/DependsOnFeeRecipient.sol";
import "../interfaces/IFeeReporter.sol";

contract Stablecoin is
    RoleAware,
    ERC20FlashMint,
    ReentrancyGuard,
    DependsOnMinterBurner,
    DependsOnFeeRecipient,
    ERC20Permit,
    IFeeReporter
{
    uint256 public globalDebtCeiling = 100_000 ether;

    uint256 public flashFeePer10k = (0.05 * 10_000) / 100;
    bool public flashLoansEnabled = true;
    uint256 public override viewAllFeesEver;

    mapping(address => uint256) public minBalance;

    constructor(address _roles)
        RoleAware(_roles)
        ERC20("MoreMoney US Dollar", "MONEY")
        ERC20Permit("MONEY")
    {
        _charactersPlayed.push(STABLECOIN);
    }

    // --------------------------- Mint / burn --------------------------------------//

    /// Mint stable, restricted to MinterBurner role (respecting global debt ceiling)
    function mint(address account, uint256 amount) external nonReentrant {
        require(isMinterBurner(msg.sender), "Not an autorized minter/burner");
        _mint(account, amount);

        require(
            globalDebtCeiling > totalSupply(),
            "Total supply exceeds global debt ceiling"
        );
    }

    /// Burn stable, restricted to MinterBurner role
    function burn(address account, uint256 amount) external nonReentrant {
        require(isMinterBurner(msg.sender), "Not an authorized minter/burner");
        _burn(account, amount);
    }

    /// Set global debt ceiling
    function setGlobalDebtCeiling(uint256 debtCeiling) external onlyOwnerExec {
        globalDebtCeiling = debtCeiling;
        emit ParameterUpdated("debt ceiling", debtCeiling);
    }

    // --------------------------- Min balances -------------------------------------//

    /// For some applications we may want to mint balances that can't be withdrawn or burnt.
    /// Contracts using this should first check balance before setting in a transaction
    function setMinBalance(address account, uint256 balance) external {
        require(isMinterBurner(msg.sender), "Not an authorized minter/burner");

        minBalance[account] = balance;
    }

    /// Check transfer and burn transactions for minimum balance compliance
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._afterTokenTransfer(from, to, amount);
        require(
            balanceOf(from) >= minBalance[from],
            "MoreMoney: below min balance"
        );
    }

    // ----------------- Flash loan related functions ------------------------------ //

    /// Calculate the fee taken on a flash loan
    function flashFee(address, uint256 amount)
        public
        view
        override
        returns (uint256)
    {
        return (amount * flashFeePer10k) / 10_000;
    }

    /// Set flash fee
    function setFlashFeePer10k(uint256 fee) external onlyOwnerExec {
        flashFeePer10k = fee;

        emit ParameterUpdated("flash fee", fee);
    }

    /// Take out a flash loan, sending fee to feeRecipient
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) public override returns (bool) {
        require(flashLoansEnabled, "Flash loans are disabled");
        uint256 fee = flashFee(token, amount);
        _mint(feeRecipient(), fee);
        viewAllFeesEver += fee;
        return super.flashLoan(receiver, token, amount, data);
    }

    /// Enable or disable flash loans
    function setFlashLoansEnabled(bool setting) external onlyOwnerExec {
        flashLoansEnabled = setting;
        emit SubjectUpdated("flash loans enabled/disabled", address(this));
    }
}
