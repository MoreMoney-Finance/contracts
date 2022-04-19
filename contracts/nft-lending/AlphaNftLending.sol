// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AlphaNftLending is ERC721Holder, ERC20Permit, Ownable {
    mapping(address => mapping(uint256 => address)) public originalOwner;
    mapping(address => mapping(uint256 => uint256)) public debt;

    mapping(address => mapping(uint256 => uint256)) public priceOracle;

    uint256 minColRatioPer10k = 14_000;
    uint256 mintingFeePer10k = (10_000 * 0.5) / 100;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) ERC20Permit(_symbol) Ownable() {}

    function mint(
        address collateralContract,
        uint256 collateralId,
        uint256 debtAmount,
        address recipient
    ) external {
        address collateralOwner = IERC721(collateralContract).ownerOf(
            collateralId
        );
        if (collateralOwner != address(this)) {
            require(
                collateralOwner == msg.sender,
                "No depositing collateral you do not own"
            );
            IERC721(collateralContract).safeTransferFrom(
                collateralOwner,
                address(this),
                collateralId
            );
            originalOwner[collateralContract][collateralId] = msg.sender;
        } else {
            require(
                originalOwner[collateralContract][collateralId] == msg.sender,
                "Not original owner of collateral"
            );
        }

        debt[collateralContract][collateralId] +=
            ((10_000 + mintingFeePer10k) * debtAmount) /
            10_000;
        require(
            !liquidatable(collateralContract, collateralId),
            "Borrow exceeds min colRatio"
        );

        _mint(recipient, debtAmount);
    }

    function burn(
        address collateralContract,
        uint256 collateralId,
        uint256 debtAmount,
        address recipient
    ) external {
        uint256 burnAmount = min(
            debt[collateralContract][collateralId],
            debtAmount
        );
        _burn(msg.sender, burnAmount);
        debt[collateralContract][collateralId] -= debtAmount;

        if (
            0.01 ether >= debt[collateralContract][collateralId] &&
            recipient == originalOwner[collateralContract][collateralId]
        ) {
            IERC721(collateralContract).safeTransferFrom(
                address(this),
                recipient,
                collateralId
            );
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a >= b) {
            return b;
        } else {
            return a;
        }
    }

    function setPriceOracle(
        address collateralContract,
        uint256 tokenId,
        uint256 oracleAmount
    ) external onlyOwner {
        priceOracle[collateralContract][tokenId] = oracleAmount;
    }

    function liquidate(
        address collateralContract,
        uint256 collateralId,
        address recipient
    ) external {
        require(
            liquidatable(collateralContract, collateralId),
            "Not liquidatable"
        );
        _burn(msg.sender, debt[collateralContract][collateralId]);
        debt[collateralContract][collateralId] = 0;
        IERC721(collateralContract).safeTransferFrom(
            address(this),
            recipient,
            collateralId
        );
    }

    function liquidatable(address collateralContract, uint256 collateralId)
        public
        view
        returns (bool)
    {
        return
            minColRatioPer10k * (debt[collateralContract][collateralId]) >
            priceOracle[collateralContract][collateralId] * 10_000;
    }
}
