// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./roles/RoleAware.sol";
import "./roles/DependsOnMinterBurner.sol";

contract Stablecoin is
    RoleAware,
    ERC20,
    ReentrancyGuard,
    DependsOnMinterBurner
{
    uint256 public globalDebtCeiling = 100_000 ether;

    constructor(address _roles) RoleAware(_roles) ERC20("Tungsten", "TNG") {}

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
}
