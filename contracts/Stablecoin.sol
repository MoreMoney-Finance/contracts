// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./roles/RoleAware.sol";
import "./roles/DependsOnMinterBurner.sol";
import "./roles/DependsOnFeeRecipient.sol";

contract Stablecoin is
    RoleAware,
    ERC20FlashMint,
    ReentrancyGuard,
    DependsOnMinterBurner,
    DependsOnFeeRecipient,
    ERC20Permit
{
    uint256 public globalDebtCeiling = 100_000 ether;
    uint256 public flashFeePer10k = (0.05 * 10_000) / 100;
    bool public flashLoansEnabled = true;

    constructor(address _roles)
        RoleAware(_roles)
        ERC20("MoreMoney US Dollar", "MONEY")
        ERC20Permit("MONEY")
    {
        _charactersPlayed.push(STABLECOIN);
    }

    function mint(address account, uint256 amount) external nonReentrant {
        require(isMinterBurner(msg.sender), "Not an autorized minter/burner");
        _mint(account, amount);

        require(
            globalDebtCeiling > totalSupply(),
            "Total supply exceeds global debt ceiling"
        );
    }

    function burn(address account, uint256 amount) external nonReentrant {
        require(isMinterBurner(msg.sender), "Not an authorized minter/burner");
        _burn(account, amount);
    }

    function setGlobalDebtCeiling(uint256 debtCeiling) external onlyOwnerExec {
        globalDebtCeiling = debtCeiling;
    }

    // ----------------- Flash loan related functions ------------------------------ //

    function flashFee(address, uint256 amount)
        public
        view
        override
        returns (uint256)
    {
        return (amount * flashFeePer10k) / 10_000;
    }

    function setFlashFeePer10k(uint256 fee) external onlyOwnerExec {
        flashFeePer10k = fee;
    }

    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) public override returns (bool) {
        require(flashLoansEnabled, "Flash loans are disabled");
        _mint(feeRecipient(), flashFee(token, amount));
        return super.flashLoan(receiver, token, amount, data);
    }

    function setFlashLoansEnabled(bool setting) external onlyOwnerExec {
        flashLoansEnabled = setting;
    }
}
