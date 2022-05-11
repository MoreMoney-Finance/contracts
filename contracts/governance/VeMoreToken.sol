// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./VeERC20.sol";

/// @title Vote Escrow More Token -veMore
/// @author Trader More
/// @notice Infinite supply, used to receive extra farming yields and voting power
contract VeMoreToken is VeERC20("VeMoreToken", "veMORE") {
    using EnumerableSet for EnumerableSet.AddressSet;

    // /// @notice the masterMore contract
    // IMasterMore public masterMore;

    /// @dev Creates `_amount` token to `_to`. Must only be called by the owner (veMoreStaking)
    /// @param _to The address that will receive the mint
    /// @param _amount The amount to be minted
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    /// @dev Destroys `_amount` tokens from `_from`. Callable only by the owner (veMoreStaking)
    /// @param _from The address that will burn tokens
    /// @param _amount The amount to be burned
    function burnFrom(address _from, uint256 _amount) external onlyOwner {
        _burn(_from, _amount);
    }
}
