// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IListener {
    function updateFactor(address, uint256) external;
}

/// @title VeERC20
/// @notice Modified version of ERC20 where transfers and allowances are disabled.
/// @dev Only minting and burning are allowed. The hook `_beforeTokenOperation` and
/// `_afterTokenOperation` methods are called before and after minting/burning respectively.
contract VeERC20 is ERC20, ERC20Permit, ERC20Votes, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private transferers;
    EnumerableSet.AddressSet private listeners;

    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
        ERC20Permit(symbol)
        Ownable()
    {
        transferers.add(address(0));
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        require(
            transferers.contains(from) || transferers.contains(to),
            "Not authorized to transfer"
        );
        super._afterTokenTransfer(from, to, amount);
        if (from != address(0)) {
            _afterTokenOperation(from);
        }
        if (to != address(0)) {
            _afterTokenOperation(to);
        }
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

    function addTransferer(address transferParticipant) external onlyOwner {
        transferers.add(transferParticipant);
    }

    function removeTransferer(address transferParticipant) external onlyOwner {
        transferers.remove(transferParticipant);
    }

    /// @notice hook called after token operation mint/burn
    /// @param _account the account being affected
    function _afterTokenOperation(address _account) internal {
        uint256 _newBalance = balanceOf(_account);
        for (uint256 i; listeners.length() > i; i++) {
            IListener(listeners.at(i)).updateFactor(_account, _newBalance);
        }
    }

    function viewTransferers() external view returns (address[] memory) {
        return transferers.values();
    }

    function viewListeners() external view returns (address[] memory) {
        return listeners.values();
    }
}
