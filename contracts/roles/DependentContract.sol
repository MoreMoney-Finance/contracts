// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Roles.sol";

abstract contract DependentContract {
    mapping(uint256 => address) public mainCharacterCache;
    mapping(address => mapping(uint256 => bool)) public roleCache;

    uint256[] public _dependsOnCharacters;
    uint256[] public _dependsOnRoles;

    uint256[] public _charactersPlayed;
    uint256[] public _rolesPlayed;

    function charactersPlayed() public view returns (uint256[] memory) {
        return _charactersPlayed;
    }

    function rolesPlayed() public view returns (uint256[] memory) {
        return _rolesPlayed;
    }

    function dependsOnCharacters() public view returns (uint256[] memory) {
        return _dependsOnCharacters;
    }

    function dependsOnRoles() public view returns (uint256[] memory) {
        return _dependsOnRoles;
    }
}
