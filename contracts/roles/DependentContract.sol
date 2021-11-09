// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Roles.sol";

/// @title DependentContract.
abstract contract DependentContract {
    mapping(uint256 => address) public mainCharacterCache;
    mapping(address => mapping(uint256 => bool)) public roleCache;

    uint256[] public _dependsOnCharacters;
    uint256[] public _dependsOnRoles;

    uint256[] public _charactersPlayed;
    uint256[] public _rolesPlayed;
    
    /** 
     * @dev charactersPlayed return the characters played
     * @return memory The characters played value in transcation
     */
    function charactersPlayed() public view returns (uint256[] memory) {
        return _charactersPlayed;
    }

    /** 
     * @dev rolesPlayed return the role played
     * @return memory The role play value in transcation
     */
    function rolesPlayed() public view returns (uint256[] memory) {
        return _rolesPlayed;
    }

    /** 
     * @dev dependsOnCharacters return the depened on character
     * @return memory The depend of character value in transcation
     */
    function dependsOnCharacters() public view returns (uint256[] memory) {
        return _dependsOnCharacters;
    }

    /** 
     * @dev dependsOnRoles return the depened on role
     * @return memory The depend of get Role value in transcation 
     */
    function dependsOnRoles() public view returns (uint256[] memory) {
        return _dependsOnRoles;
    }
}