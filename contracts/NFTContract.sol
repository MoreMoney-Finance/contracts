// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./MetaLending.sol";
import "./roles/RoleAware.sol";
import "./roles/Roles.sol";

contract NFTContract is ERC721URIStorage, ReentrancyGuard, RoleAware {
    using Counters for Counters.Counter;
    uint256 public constant INITIAL_LIMIT = 100;
    uint256 public constant LIMIT_DOUBLING_PERIOD = 10 days;
    uint256 public constant MINIMUM_DEBT = 100 * 10 ** 18;
    MetaLending public metaLending;

    uint256 public nftLimit;
    uint256 public startTime;
    uint256 public minimumDebt;

    uint256 public totalSupply;
    Counters.Counter private _tokenIds;

    // Mapping to store the trancheId associated with each tokenId
    mapping(uint256 => uint256) private _trancheIdByTokenId;

    constructor(
        address roles,
        address _metaLending
    ) ERC721("NFTContract", "MMSMOL") RoleAware(roles) {
        _charactersPlayed.push(NFT_CLAIMER);
        metaLending = MetaLending(_metaLending);
        nftLimit = INITIAL_LIMIT;
        startTime = block.timestamp;
        minimumDebt = MINIMUM_DEBT;
        totalSupply = 0;
    }

    /// Claim NFT
    function claimNFT() external virtual nonReentrant {
        // Check if the time limit is over
        if (block.timestamp >= startTime + LIMIT_DOUBLING_PERIOD) {
            // Double the minimumDebt, nftLimit, and LIMIT_DOUBLING_PERIOD
            minimumDebt *= 2;
            nftLimit *= 2;
            startTime = block.timestamp;
        }

        // Check if NFT limit is reached
        require(totalSupply < nftLimit, "NFT limit reached");

        // Fetch user's positions and calculate total debt
        uint256[] memory trancheIds = metaLending.viewTranchesByOwner(
            msg.sender
        );
        MetaLending.PositionMetadata[]
            memory positions = new MetaLending.PositionMetadata[](
                trancheIds.length
            );
        for (uint256 i; trancheIds.length > i; i++) {
            uint256 _trancheId = trancheIds[i];
            positions[i] = metaLending.viewPositionMetadata(_trancheId);
        }
        uint256 totalUserDebt = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            totalUserDebt += positions[i].debt;
        }

        // Check if user meets the minimum debt requirement
        require(totalUserDebt >= minimumDebt, "Not enough debt");

        // Check if user already owns an NFT for each trancheId
        for (uint256 i = 0; i < trancheIds.length; i++) {
            uint256 _trancheId = trancheIds[i];
            require(
                !_userOwnsNFTForTrancheId(msg.sender, _trancheId),
                "NFT already owned for this trancheId"
            );
        }

        // Mint the NFT
        _tokenIds.increment();
        totalSupply++;
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);

        // Associate the trancheId with the tokenId
        for (uint256 i = 0; i < trancheIds.length; i++) {
            uint256 _trancheId = trancheIds[i];
            _trancheIdByTokenId[newItemId] = _trancheId;
        }
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
}
