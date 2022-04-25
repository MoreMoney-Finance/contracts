// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

interface IVeMoreNFT is IERC721Enumerable, IERC2981 {
    struct VeMore {
        uint32 power;
        uint16 level;
        uint16 score;
        // Attributes ( 0 - 6 | E2 E1 D2 D1 C B A)
        uint8 eyes;
        uint8 mouth;
        uint8 foot;
        uint8 body;
        uint8 tail;
        uint8 accessories;
        // Abilities
        // 0 - Speedo
        // 1 - Pudgy
        // 2 - Diligent
        // 3 - Gifted
        // 4 - Hibernate
        uint8 ability;
    }

    /*///////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    function mintCost() external view returns (uint256);

    function merkleRoot() external view returns (bytes32);

    function availableTotalSupply() external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
        CONTRACT MANAGEMENT OPERATIONS / SALES
    //////////////////////////////////////////////////////////////*/
    function setOwner(address newOwner) external;

    function increaseAvailableTotalSupply(uint256 amount) external;

    function changeMintCost(uint256 cost) external;

    function setSaleDetails(bytes32 _root, uint256 _preSaleDeadline) external;

    function preSaleDeadline() external view returns (uint256);

    function usedPresaleTicket(address) external view returns (bool);

    function withdrawLINK() external;

    function withdrawVeMore() external;

    function setNewRoyaltyDetails(address _newAddress, uint256 _newFee)
        external;

    /*///////////////////////////////////////////////////////////////
                        VeMore LEVEL MECHANICS
            Caretakers are other authorized contracts that
                according to their own logic can issue aVeMore 
                    to level up
    //////////////////////////////////////////////////////////////*/
    function caretakers(address) external view returns (uint256);

    function addCaretaker(address caretaker) external;

    function removeCaretaker(address caretaker) external;

    function levelUp(uint256 tokenId) external;

    /*///////////////////////////////////////////////////////////////
                           VeMore 
    //////////////////////////////////////////////////////////////*/

    function getVeMoreDetails(uint256 tokenId)
        external
        view
        returns (
            uint16 level,
            uint8 ability,
            uint32 power
        );

    function VeMorees(uint256)
        external
        view
        returns (
            uint32 power,
            uint16 level,
            uint16 score,
            uint8 eyes,
            uint8 mouth,
            uint8 foot,
            uint8 body,
            uint8 tail,
            uint8 accessories,
            uint8 ability
        );

    function VeMoreesLength() external view returns (uint256);

    function setBaseURI(string memory _baseURI) external;

    /*///////////////////////////////////////////////////////////////
                            MINTING
    //////////////////////////////////////////////////////////////*/
    function requestMint(uint256 numberOfMints) external;

    function requestMintTicket(uint256 numberOfMints, bytes32[] memory proof)
        external;

    function supportsInterface(bytes4 interfaceId)
        external
        view
        override
        returns (bool);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event MintRequest(uint256 from, uint256 length);
    event OwnerUpdated(address indexed newOwner);
    event VeMoreCreation(uint256 from, uint256 length);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    // temporarily commented as errors is not yet supported by slither
    // ref: https://github.com/crytic/slither/issues/893
    // error FeeTooHigh();
    // error InvalidCaretaker();
    // error InvalidRequestID();
    // error InvalidTokenID();
    // error MintLimit();
    // error PreSaleEnded();
    // error TicketError();
    // error TooSoon();
    // error Unauthorized();
}
