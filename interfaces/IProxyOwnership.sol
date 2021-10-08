// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IProxyOwnership {
    function containedIn(address tokenContract, uint256 tokenId) external view returns (uint256);
    function isProxy(address tokenContract, uint256 tokenId, address spender) external view returns (bool);
    function checkProxyAuthorization(address tokenContract, uint256 tokenId, address spender) external view returns (bool);
    function checkViability(uint256 tokenId) external view returns (bool);
}