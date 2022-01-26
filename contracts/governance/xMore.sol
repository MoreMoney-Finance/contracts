// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract xMore is ERC20("xMORE", "xMORE") {
    IERC20 public immutable more;

    constructor(IERC20 _more) {
        more = _more;
    }

    // Locks MORE and mints xMORE
    function enter(uint256 _amount) public {
        // Gets the amount of MORE locked in the contract
        uint256 totalMore = more.balanceOf(address(this));
        // Gets the amount of xMORE in existence
        uint256 totalShares = totalSupply();
        // If no xMore exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalMore == 0) {
            _mint(msg.sender, _amount);
        }
        // Calculate and mint the amount of xMORE the More is worth.
        // The ratio will change overtime, as xMORE is burned/minted and More deposited + gained from fees / withdrawn.
        else {
            uint256 what = (_amount * totalShares) / totalMore;
            _mint(msg.sender, what);
        }
        // Lock the More in the contract
        more.transferFrom(msg.sender, address(this), _amount);
    }

    // Unlocks the staked + gained MORE and burns xMORE
    function leave(uint256 _share) public {
        // Gets the amount of xMore in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of More the xMore is worth
        uint256 what = (_share * more.balanceOf(address(this))) / totalShares;
        _burn(msg.sender, _share);
        more.transfer(msg.sender, what);
    }
}
