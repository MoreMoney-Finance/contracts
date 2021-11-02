// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Executor.sol";

import "../DependencyController.sol";

contract DependencyCleaner is Executor {
    address[] contracts;
    uint256[] roles2nix;

    constructor(
        address[] memory _contracts,
        uint256[] memory _roles2nix,
        address _roles
    ) RoleAware(_roles) {
        contracts = _contracts;
        roles2nix = _roles2nix;
    }

    function execute() external override {
        DependencyController dc = DependencyController(msg.sender);
        for (uint256 i; contracts.length > i; i++) {
            dc.removeRole(roles2nix[i], contracts[i]);
        }

        delete contracts;
        delete roles2nix;
        selfdestruct(payable(tx.origin));
    }
}
