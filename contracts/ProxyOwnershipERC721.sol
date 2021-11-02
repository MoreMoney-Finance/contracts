// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/IProxyOwnership.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

abstract contract ProxyOwnershipERC721 is ERC721Enumerable, IProxyOwnership {
    using Address for address;

    mapping(uint256 => uint256) public _containedIn;

    function containedIn(uint256 tokenId)
        public
        view
        override
        returns (address owner, uint256 containerId)
    {
        return (ownerOf(tokenId), _containedIn[tokenId]);
    }

    function isAuthorized(address spender, uint256 tokenId)
        public
        view
        override
        returns (bool)
    {
        address tokenOwner = ownerOf(tokenId);
        return
            _isApprovedOrOwner(spender, tokenId) ||
            (tokenOwner.isContract() &&
                IProxyOwnership(tokenOwner).isAuthorized(
                    spender,
                    _containedIn[tokenId]
                ));
    }
}
