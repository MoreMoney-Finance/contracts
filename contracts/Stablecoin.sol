// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./RoleAware.sol";

contract Stablecoin is RoleAware, ERC20, ReentrancyGuard {
    constructor(address _roles) RoleAware(_roles) ERC20("Tungsten", "TNG") {}

    function mint(address account, uint256 amount) external {
        require(isMinterBurner(msg.sender), "Not an autorized minter/burner");
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        require(isMinterBurner(msg.sender), "Not an authorized minter/burner");
        _burn(account, amount);
    }
}
