// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./roles/RoleAware.sol";
import "./Executor.sol";
import "../interfaces/IDependencyController.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./roles/DependentContract.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title Provides a single point of reference to verify integrity
/// of the roles structure and facilitate governance actions
/// within our system as well as performing cache invalidation for
/// roles and inter-contract relationships
contract DependencyController is
    RoleAware,
    IDependencyController,
    ReentrancyGuard
{
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(address _roles) RoleAware(_roles) {}

    address public override currentExecutor;

    EnumerableSet.AddressSet internal managedContracts;

    mapping(address => uint256[]) public roleDependenciesByContr;
    mapping(address => uint256[]) public characterDependenciesByContr;
    mapping(uint256 => EnumerableSet.AddressSet) internal dependentsByRole;
    mapping(uint256 => EnumerableSet.AddressSet) internal dependentsByCharacter;

    mapping(uint256 => EnumerableSet.AddressSet) internal knownRoleHolders;

    /// Run an executor contract in the executor role (which has ownership privileges throughout)
    function executeAsOwner(address executor) external onlyOwner nonReentrant {
        uint256[] memory requiredRoles = Executor(executor).rolesPlayed();
        uint256[] memory requiredCharacters = Executor(executor)
            .charactersPlayed();
        address[] memory extantCharacters = new address[](
            requiredCharacters.length
        );

        for (uint256 i = 0; requiredRoles.length > i; i++) {
            _giveRole(requiredRoles[i], executor);
        }

        for (uint256 i = 0; requiredCharacters.length > i; i++) {
            extantCharacters[i] = roles.mainCharacters(requiredCharacters[i]);
            _setMainCharacter(requiredCharacters[i], executor);
        }

        uint256[] memory dependsOnCharacters = DependentContract(executor)
            .dependsOnCharacters();
        uint256[] memory dependsOnRoles = DependentContract(executor)
            .dependsOnRoles();
        characterDependenciesByContr[executor] = dependsOnCharacters;
        roleDependenciesByContr[executor] = dependsOnRoles;

        updateCaches(executor);
        currentExecutor = executor;
        Executor(executor).execute();
        currentExecutor = address(0);

        uint256 len = requiredRoles.length;
        for (uint256 i = 0; len > i; i++) {
            _removeRole(requiredRoles[i], executor);
        }

        for (uint256 i = 0; requiredCharacters.length > i; i++) {
            _setMainCharacter(requiredCharacters[i], extantCharacters[i]);
        }
    }

    /// Orchestrate roles and permission for contract
    function manageContract(address contr) external onlyOwnerExec {
        _manageContract(contr);
    }

    /// Orchestrate roles and permission for contract
    function _manageContract(address contr) internal {
        managedContracts.add(contr);

        uint256[] memory charactersPlayed = DependentContract(contr)
            .charactersPlayed();
        uint256[] memory rolesPlayed = DependentContract(contr).rolesPlayed();

        // set up all characters this contract plays
        uint256 len = charactersPlayed.length;
        for (uint256 i = 0; len > i; i++) {
            uint256 character = charactersPlayed[i];
            _setMainCharacter(character, contr);
        }

        // all roles this contract plays
        len = rolesPlayed.length;
        for (uint256 i = 0; len > i; i++) {
            uint256 role = rolesPlayed[i];
            _giveRole(role, contr);
        }

        uint256[] memory dependsOnCharacters = DependentContract(contr)
            .dependsOnCharacters();
        uint256[] memory dependsOnRoles = DependentContract(contr)
            .dependsOnRoles();
        characterDependenciesByContr[contr] = dependsOnCharacters;
        roleDependenciesByContr[contr] = dependsOnRoles;

        for (uint256 i; dependsOnCharacters.length > i; i++) {
            dependentsByCharacter[dependsOnCharacters[i]].add(contr);
        }
        for (uint256 i; dependsOnRoles.length > i; i++) {
            dependentsByRole[dependsOnRoles[i]].add(contr);
        }

        updateCaches(contr);
    }

    /// Completely replace and disable old while enabling new contract
    /// Caution: no checks made that replacement contract is semantically aligned
    /// or hitherto unmanaged
    function replaceContract(address contract2Disable, address contract2Enable)
        external
        onlyOwnerExec
    {
        _disableContract(contract2Disable);
        _manageContract(contract2Enable);
    }

    ///  Remove roles and permissions for contract
    function disableContract(address contr) external onlyOwnerExecDisabler {
        _disableContract(contr);
    }

    /// Completely remove all roles, characters and un-manage a contract
    function _disableContract(address contr) internal {
        managedContracts.remove(contr);

        uint256[] memory charactersPlayed = DependentContract(contr)
            .charactersPlayed();
        uint256[] memory rolesPlayed = DependentContract(contr).rolesPlayed();

        uint256 len = rolesPlayed.length;
        for (uint256 i = 0; len > i; i++) {
            if (roles.roles(contr, rolesPlayed[i])) {
                _removeRole(rolesPlayed[i], contr);
            }
        }

        len = charactersPlayed.length;
        for (uint256 i = 0; len > i; i++) {
            if (roles.mainCharacters(charactersPlayed[i]) == contr) {
                _setMainCharacter(charactersPlayed[i], address(0));
            }
        }

        uint256[] storage dependsOnCharacters = characterDependenciesByContr[
            contr
        ];
        len = dependsOnCharacters.length;
        for (uint256 i; len > i; i++) {
            dependentsByCharacter[dependsOnCharacters[i]].remove(contr);
        }

        uint256[] storage dependsOnRoles = roleDependenciesByContr[contr];
        len = dependsOnRoles.length;
        for (uint256 i; len > i; i++) {
            dependentsByRole[dependsOnRoles[i]].remove(contr);
        }
    }

    /// Activate role
    function giveRole(uint256 role, address actor) external onlyOwnerExec {
        _giveRole(role, actor);
    }

    /// Disable role
    function removeRole(uint256 role, address actor)
        external
        onlyOwnerExecDisabler
    {
        _removeRole(role, actor);
    }

    /// Un-assign a role, notifying all contracts depending on that role
    function _removeRole(uint256 role, address actor) internal {
        knownRoleHolders[role].remove(actor);
        roles.removeRole(role, actor);
        updateRoleCache(role, actor);
    }

    /// Assign main character
    function setMainCharacter(uint256 role, address actor)
        external
        onlyOwnerExec
    {
        _setMainCharacter(role, actor);
    }

    /// Assign a role, notifying all depending contracts
    function _giveRole(uint256 role, address actor) internal {
        knownRoleHolders[role].add(actor);
        roles.giveRole(role, actor);
        updateRoleCache(role, actor);
    }

    /// Assign main character, notifying all depending contracts
    function _setMainCharacter(uint256 character, address actor) internal {
        roles.setMainCharacter(character, actor);
        updateMainCharacterCache(character);
    }

    /// Notify all dependent contracts after main character change
    function updateMainCharacterCache(uint256 character) public override {
        EnumerableSet.AddressSet storage listeners = dependentsByCharacter[
            character
        ];
        uint256 len = listeners.length();
        for (uint256 i = 0; len > i; i++) {
            RoleAware(listeners.at(i)).updateMainCharacterCache(character);
        }
    }

    /// Notify all dependent contracts after role change
    function updateRoleCache(uint256 role, address contr) public override {
        EnumerableSet.AddressSet storage listeners = dependentsByRole[role];
        uint256 len = listeners.length();
        for (uint256 i = 0; len > i; i++) {
            RoleAware(listeners.at(i)).updateRoleCache(role, contr);
        }
    }

    /// Update cached value for all the dependencies of a contract
    function updateCaches(address contr) public {
        // update this contract with all characters it's listening to
        uint256[] storage dependsOnCharacters = characterDependenciesByContr[
            contr
        ];
        uint256 len = dependsOnCharacters.length;
        for (uint256 i = 0; len > i; i++) {
            RoleAware(contr).updateMainCharacterCache(dependsOnCharacters[i]);
        }

        // update this contract with all the roles it's listening to
        uint256[] storage dependsOnRoles = roleDependenciesByContr[contr];
        len = dependsOnRoles.length;
        for (uint256 i = 0; len > i; i++) {
            uint256 role = dependsOnRoles[i];
            EnumerableSet.AddressSet storage knownHolders = knownRoleHolders[
                role
            ];
            for (uint256 j = 0; knownHolders.length() > j; j++) {
                RoleAware(contr).updateRoleCache(role, knownHolders.at(j));
            }
        }
    }

    /// All the contracts managed by this controller
    function allManagedContracts() external view returns (address[] memory) {
        return managedContracts.values();
    }
}
