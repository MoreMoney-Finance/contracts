// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./roles/RoleAware.sol";
import "./TrancheIDService.sol";
import "./roles/DependsOnTrancheIDService.sol";

abstract contract TrancheIDAware is RoleAware, DependsOnTrancheIDService {
    uint256 immutable totalTrancheSlots;

    constructor(address _roles) RoleAware(_roles) {
        totalTrancheSlots = TrancheIDService(
            Roles(_roles).mainCharacters(TRANCHE_ID_SERVICE)
        ).totalTrancheSlots();
    }

    mapping(uint256 => address) _slotTranches;

    function tranche(uint256 trancheId) public view returns (address) {
        uint256 slot = trancheId % totalTrancheSlots;
        address trancheContract = _slotTranches[slot];
        if (trancheContract == address(0)) {
            trancheContract = trancheIdService().slotTranches(slot);
        }

        return trancheContract;
    }
}
