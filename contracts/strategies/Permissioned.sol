// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract Permissioned is Ownable {
    using SafeMath for uint256;

    uint256 public numberOfAllowedDepositors;
    mapping(address => bool) public allowedDepositors;

    event AllowDepositor(address indexed account);
    event RemoveDepositor(address indexed account);

    modifier onlyAllowedDeposits() {
        if (numberOfAllowedDepositors > 0) {
            require(
                allowedDepositors[msg.sender] == true,
                "Permissioned::onlyAllowedDeposits, not allowed"
            );
        }
        _;
    }

    /**
     * @notice Add an allowed depositor
     * @param depositor address
     */
    function allowDepositor(address depositor) external onlyOwner {
        require(
            allowedDepositors[depositor] == false,
            "Permissioned::allowDepositor"
        );
        allowedDepositors[depositor] = true;
        numberOfAllowedDepositors = numberOfAllowedDepositors.add(1);
        emit AllowDepositor(depositor);
    }

    /**
     * @notice Remove an allowed depositor
     * @param depositor address
     */
    function removeDepositor(address depositor) external onlyOwner {
        require(
            numberOfAllowedDepositors > 0,
            "Permissioned::removeDepositor, no allowed depositors"
        );
        require(
            allowedDepositors[depositor] == true,
            "Permissioned::removeDepositor, not allowed"
        );
        allowedDepositors[depositor] = false;
        numberOfAllowedDepositors = numberOfAllowedDepositors.sub(1);
        emit RemoveDepositor(depositor);
    }
}
