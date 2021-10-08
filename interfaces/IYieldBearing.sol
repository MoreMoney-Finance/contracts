// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IYieldBearing {
    function getYield(address currency, uint256 tokenId, address recipient) external;
    function viewYield(address currency, uint256 tokenId) external view returns (uint256);

    function migrateTrancheTo(uint256 trancheId, address destination) external;
}