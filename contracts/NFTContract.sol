// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./roles/RoleAware.sol";
import "./roles/Roles.sol";

contract NFTContract is ERC721URIStorage, ReentrancyGuard, RoleAware, EIP712 {
    using Counters for Counters.Counter;

    struct MintData {
        address minter;
        uint256 epoch;
    }

    mapping(address => mapping(uint256 => bool)) public usedSignatures;
    mapping(uint256 => MintData) public tokenIdToMintData;

    Counters.Counter private _tokenIdCounter;

    uint256 public currentEpoch;
    uint256 public slotsPerEpoch;
    uint256 public mintsInCurrentEpoch;

    constructor(
        address roles,
        uint256 _slotsPerEpoch
    )
        ERC721("NFTContract", "MMSMOL")
        RoleAware(roles)
        EIP712("NFTContract", "1")
    {
        _charactersPlayed.push(NFT_CLAIMER);
        currentEpoch = block.timestamp;
        slotsPerEpoch = _slotsPerEpoch;
        mintsInCurrentEpoch = 0;
    }

    function mintNFT(
        MintData calldata mintData,
        bytes memory signature
    ) external payable nonReentrant {
        require(mintData.epoch == currentEpoch, "Invalid epoch for minting");
        require(
            mintsInCurrentEpoch < slotsPerEpoch,
            "All slots for the current epoch have been filled"
        );
        require(
            !usedSignatures[mintData.minter][mintData.epoch],
            "Signature has already been used"
        );
        require(
            verifyMintData(mintData, signature),
            "Verification of mint data failed"
        );

        _tokenIdCounter.increment();
        uint256 newItemId = _tokenIdCounter.current();
        _mint(msg.sender, newItemId);
        tokenIdToMintData[newItemId] = mintData;

        mintsInCurrentEpoch++;
        usedSignatures[mintData.minter][mintData.epoch] = true;
    }

    function verifyMintData(
        MintData memory mintData,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("MintData(address minter,uint256 epoch)"),
                    mintData.minter,
                    mintData.epoch
                )
            )
        );
        address signer = ECDSA.recover(digest, signature);
        return owner() == signer;
    }

    function setCurrentEpoch(uint256 epoch) external onlyOwner {
        currentEpoch = epoch;
        mintsInCurrentEpoch = 0;
    }

    function setSlotsPerEpoch(uint256 slots) external onlyOwner {
        slotsPerEpoch = slots;
        mintsInCurrentEpoch = 0;
    }

    function viewMintData(
        uint256 tokenId
    ) external view returns (MintData memory) {
        return tokenIdToMintData[tokenId];
    }
}
