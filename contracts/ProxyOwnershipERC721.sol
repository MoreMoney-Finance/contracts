// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/IProxyOwnership.sol";
import "../interfaces/IYieldBearing.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

abstract contract ProxyOwnershipERC721 is ERC721Enumerable, IProxyOwnership, IYieldBearing {
    using Address for address;
    mapping(address => mapping(uint256 => uint256)) public override containedIn;

    function isProxy(address tokenContract, uint256 tokenId, address spender) public virtual override view returns (bool) {
        return ownerOf(containedIn[tokenContract][tokenId]) == spender;
    }

    function _checkApprovedOwnerOrProxy(address spender, uint256 tokenId) internal virtual view {
        address tokenOwner = ownerOf(tokenId);
        bool check = _isApprovedOrOwner(spender, tokenId) || (tokenOwner.isContract() && IProxyOwnership(tokenOwner).checkProxyAuthorization(address(this), tokenId, spender));
        require(check, "Not authorized to take action on asset");
    }

    function checkProxyAuthorization(address tokenContract, uint256 tokenId, address spender) public virtual override view returns (bool) {
        _checkApprovedOwnerOrProxy(spender, containedIn[tokenContract][tokenId]);
        return true;
    }
}