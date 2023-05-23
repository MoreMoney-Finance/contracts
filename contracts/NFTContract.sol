// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./MetaLending.sol";
import "./WrapNativeStableLending.sol";
import "./roles/RoleAware.sol";
import "./roles/Roles.sol";

contract NFTContract is ERC721URIStorage, ReentrancyGuard, RoleAware {
    using Counters for Counters.Counter;
    uint256 public constant INITIAL_LIMIT = 100;
    uint256 public constant LIMIT_DOUBLING_PERIOD = 10 days;
    uint256 public constant MINIMUM_DEBT = 100 * 10 ** 18;
    MetaLending public metaLending;
    WrapNativeStableLending public wrapNativeStableLending;

    uint256 public nftLimit;
    uint256 public startTime;
    uint256 public minimumDebt;

    uint256 public totalSupply;
    Counters.Counter private _tokenIds;

    // Mapping to store the trancheId associated with each tokenId
    mapping(uint256 => uint256) private _trancheIdByTokenId;

    constructor(
        address roles,
        address _metaLending,
        address _wrapNativeMetaLending
    ) ERC721("NFTContract", "MMSMOL") RoleAware(roles) {
        _charactersPlayed.push(NFT_CLAIMER);
        metaLending = MetaLending(_metaLending);
        wrapNativeStableLending = WrapNativeStableLending(
            _wrapNativeMetaLending
        );
        nftLimit = INITIAL_LIMIT;
        startTime = block.timestamp;
        minimumDebt = MINIMUM_DEBT;
        totalSupply = 0;
    }

    /// Claim NFT
    function claimNFT() external virtual nonReentrant {
        require(canIClaim(), "Cannot claim NFT");

        // Mint the NFT
        _tokenIds.increment();
        totalSupply++;
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);

        // Associate the trancheId with the tokenId
        uint256[] memory trancheIds = metaLending.viewTranchesByOwner(
            msg.sender
        );
        for (uint256 i = 0; i < trancheIds.length; i++) {
            uint256 _trancheId = trancheIds[i];
            _trancheIdByTokenId[newItemId] = _trancheId;
        }
    }

    /// Check if the user is allowed to claim an NFT based on the same rules as minting
    function canIClaim() public view returns (bool) {
        return
            isTimeLimitOver() &&
            hasMinimumDebt() &&
            hasAvailableNFT() &&
            !hasDuplicateNFTs();
    }

    /// Check if the time limit is over
    function isTimeLimitOver() internal view returns (bool) {
        return block.timestamp >= startTime + LIMIT_DOUBLING_PERIOD;
    }

    /// Check if the user meets the minimum debt requirement
    function hasMinimumDebt() internal view returns (bool) {
        uint256 totalUserDebt = getTotalUserDebt();
        return totalUserDebt >= minimumDebt;
    }

    /// Check if the NFT limit is reached
    function hasAvailableNFT() internal view returns (bool) {
        return totalSupply < nftLimit;
    }

    /// Check if the user already owns an NFT for each trancheId
    function hasDuplicateNFTs() internal view returns (bool) {
        uint256[] memory trancheIds = metaLending.viewTranchesByOwner(
            msg.sender
        );
        for (uint256 i = 0; i < trancheIds.length; i++) {
            uint256 _trancheId = trancheIds[i];
            if (_userOwnsNFTForTrancheId(msg.sender, _trancheId)) {
                return true;
            }
        }
        return false;
    }

    /// Calculate the total debt of the user across lending protocols
    function getTotalUserDebt() internal view returns (uint256) {
        uint256 totalUserDebt = 0;
        totalUserDebt += metaLendingTotalUserDebt(msg.sender);
        totalUserDebt += wrapNativeStableLendingTotalUserDebt(msg.sender);
        return totalUserDebt;
    }

    /// Check if the user already owns an NFT for a given trancheId
    function _userOwnsNFTForTrancheId(
        address user,
        uint256 trancheId
    ) internal view returns (bool) {
        for (uint256 i = 1; i <= totalSupply; i++) {
            if (
                _exists(i) &&
                _trancheIdByTokenId[i] == trancheId &&
                ownerOf(i) == user
            ) {
                return true;
            }
        }
        return false;
    }

    /// Get the total user debt in MetaLending
    function metaLendingTotalUserDebt(
        address user
    ) internal view returns (uint256) {
        uint256[] memory trancheIds = metaLending.viewTranchesByOwner(user);
        MetaLending.PositionMetadata[]
            memory positions = new MetaLending.PositionMetadata[](
                trancheIds.length
            );
        for (uint256 i = 0; i < trancheIds.length; i++) {
            uint256 _trancheId = trancheIds[i];
            positions[i] = metaLending.viewPositionMetadata(_trancheId);
        }
        uint256 totalUserDebt = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            totalUserDebt += positions[i].debt;
        }
        return totalUserDebt;
    }

    /// Get the total user debt in WrapNativeStableLending
    function wrapNativeStableLendingTotalUserDebt(
        address user
    ) internal view returns (uint256) {
        uint256[] memory trancheIds = wrapNativeStableLending
            .viewTranchesByOwner(user);
        WrapNativeStableLending.PositionMetadata[]
            memory positions = new WrapNativeStableLending.PositionMetadata[](
                trancheIds.length
            );
        for (uint256 i = 0; i < trancheIds.length; i++) {
            uint256 _trancheId = trancheIds[i];
            positions[i] = wrapNativeStableLending.viewPositionMetadata(
                _trancheId
            );
        }
        uint256 totalUserDebt = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            totalUserDebt += positions[i].debt;
        }
        return totalUserDebt;
    }
}
