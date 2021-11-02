// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

// TODO naming of these different proxy functions

interface IProxyOwnership {
    function containedIn(uint256 tokenId)
        external
        view
        returns (address containerAddress, uint256 containerId);

    function isAuthorized(address spender, uint256 tokenId)
        external
        view
        returns (bool);

    function isViable(uint256 tokenId) external view returns (bool);
}
