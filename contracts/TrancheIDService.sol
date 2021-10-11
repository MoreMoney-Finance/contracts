// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./RoleAware.sol";

contract TrancheIDService is RoleAware {
    uint256 public constant totalTrancheSlots = 1e8;
    uint256 public nextTrancheSlot = 1;

    struct TrancheSlot {
        uint256 nextTrancheIdRange;
        uint256 trancheSlot;
    }

    mapping(address => TrancheSlot) public trancheSlots;
    mapping(uint256 => address) public slotTranches;

    constructor(address _roles) RoleAware(_roles) {}

    function getNextTrancheId() external returns (uint256 id) {
        require(isTranche(msg.sender), "Caller not a tranche contract");
        TrancheSlot storage slot = trancheSlots[msg.sender];
        require(slot.trancheSlot != 0, "Caller doesn't have a slot");
        id = slot.nextTrancheIdRange * totalTrancheSlots + slot.trancheSlot;
        slot.nextTrancheIdRange++;
    }

    function setupTrancheSlot() external returns (TrancheSlot memory) {
        require(isTranche(msg.sender), "Caller not a tranche contract");
        require(
            trancheSlots[msg.sender].trancheSlot == 0,
            "Tranche already has a slot"
        );
        trancheSlots[msg.sender] = TrancheSlot({
            nextTrancheIdRange: 1,
            trancheSlot: nextTrancheSlot
        });
        slotTranches[nextTrancheSlot] = msg.sender;
        nextTrancheSlot++;
        return trancheSlots[msg.sender];
    }

    function viewNextTrancheId(address trancheContract)
        external
        view
        returns (uint256)
    {
        TrancheSlot storage slot = trancheSlots[trancheContract];
        return slot.nextTrancheIdRange * totalTrancheSlots + slot.trancheSlot;
    }

    function getTrancheContractByID(uint256 trancheId)
        external
        view
        returns (address)
    {
        return slotTranches[trancheId % totalTrancheSlots];
    }
}
