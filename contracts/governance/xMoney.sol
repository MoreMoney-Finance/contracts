// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract xMoney is ERC20, ERC20Permit, ERC20Votes {
    IERC20 public immutable money;

    constructor(IERC20 _money) ERC20("xMONEY", "xMONEY") ERC20Permit("xMONEY") {
        money = _money;
    }

    // Locks MONEY and mints xMONEY
    function deposit(uint256 _amount) public {
        // Gets the amount of MONEY locked in the contract
        uint256 totalMore = money.balanceOf(address(this));
        // Gets the amount of xMONEY in existence
        uint256 totalShares = totalSupply();
        // If no xMoney exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalMore == 0) {
            _mint(msg.sender, _amount);
        }
        // Calculate and mint the amount of xMONEY the More is worth.
        // The ratio will change overtime, as xMONEY is burned/minted
        // and MONEY deposited + gained from fees / withdrawn.
        else {
            uint256 what = (_amount * totalShares) / totalMore;
            _mint(msg.sender, what);
        }
        // Lock the More in the contract
        money.transferFrom(msg.sender, address(this), _amount);
    }

    // Unlocks the staked + gained MONEY and burnsxMONEY
    function withdraw(uint256 _share) public {
        // Gets the amount of xMoney in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of More the xMoney is worth
        uint256 what = (_share * money.balanceOf(address(this))) / totalShares;
        _burn(msg.sender, _share);
        money.transfer(msg.sender, what);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
