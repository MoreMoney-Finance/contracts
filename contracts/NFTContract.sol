// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IStableLending2.sol";
import "./roles/RoleAware.sol";
import "./roles/Roles.sol";

contract NFTContract is ERC721URIStorage, ReentrancyGuard, RoleAware {
    using Counters for Counters.Counter;
    uint256 public constant INITIAL_LIMIT = 100;
    uint256 public constant LIMIT_DOUBLING_PERIOD = 10 days;
    uint256 public constant MINIMUM_DEBT = 100 * 10 ** 18;
    IStableLending2 public stableLending2;

    uint256 public nftLimit;
    uint256 public startTime;
    uint256 public minimumDebt;

    uint256 public totalSupply;
    Counters.Counter private _tokenIds;

    string public baseURI =
        "https://raw.githubusercontent.com/MoreMoney-Finance/contracts/feature/smol-pp/nfts/metadata/";

    // Mapping to store the trancheId associated with each tokenId
    mapping(uint256 => uint256) private _trancheIdByTokenId;

    // Mapping to store the tokenId associated with each trancheId
    mapping(uint256 => uint256) private _tokenIdByTrancheId;

    constructor(
        address roles,
        address _stableLending2
    ) ERC721("NFTContract", "MMSMOL") RoleAware(roles) {
        _charactersPlayed.push(NFT_CLAIMER);
        stableLending2 = IStableLending2(_stableLending2);
        nftLimit = INITIAL_LIMIT;
        startTime = block.timestamp;
        minimumDebt = MINIMUM_DEBT;
        totalSupply = 0;
    }

    function concat(
        bytes memory a,
        bytes memory b
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(a, b);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );

        string memory _tokenURI = string(
            concat(bytes(baseURI), bytes(Strings.toString(tokenId)))
        );
        return _tokenURI;
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
        uint256[] memory trancheIds = stableLending2.viewTranchesByOwner(
            msg.sender
        );
        for (uint256 i = 0; i < trancheIds.length; i++) {
            uint256 _trancheId = trancheIds[i];
            _trancheIdByTokenId[newItemId] = _trancheId;
            _tokenIdByTrancheId[_trancheId] = newItemId;
        }
    }

    // Get the trancheId associated with a tokenId
    function trancheIdByTokenId(
        uint256 tokenId
    ) external view returns (uint256) {
        return _trancheIdByTokenId[tokenId];
    }

    // Get the tokenId associated with a trancheId
    function tokenIdByTrancheId(
        uint256 trancheId
    ) external view returns (uint256) {
        return _tokenIdByTrancheId[trancheId];
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
        uint256[] memory trancheIds = stableLending2.viewTranchesByOwner(
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
        totalUserDebt += iStableLending2TotalUserDebt(msg.sender);
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

    /// Get the total user debt in IStableLending2
    function iStableLending2TotalUserDebt(
        address user
    ) internal view returns (uint256) {
        uint256[] memory trancheIds = stableLending2.viewTranchesByOwner(user);
        IStableLending2.PositionMetadata[]
            memory positions = new IStableLending2.PositionMetadata[](
                trancheIds.length
            );
        for (uint256 i = 0; i < trancheIds.length; i++) {
            uint256 _trancheId = trancheIds[i];
            positions[i] = stableLending2.viewPositionMetadata(_trancheId);
        }
        uint256 totalUserDebt = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            totalUserDebt += positions[i].debt;
        }
        return totalUserDebt;
    }
}
