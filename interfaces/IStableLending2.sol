// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IStableLending2 {
    struct ILMetadata {
        uint256 debtCeiling;
        uint256 totalDebt;
        uint256 mintingFee;
        uint256 borrowablePer10k;
    }

    struct PositionMetadata {
        uint256 trancheId;
        address strategy;
        uint256 collateral;
        uint256 debt;
        address token;
        uint256 yield;
        uint256 collateralValue;
        uint256 borrowablePer10k;
        address owner;
    }

    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );
    event ParameterUpdated(string param, uint256 value);
    event SubjectParameterUpdated(string param, address subject, uint256 value);
    event SubjectUpdated(string param, address subject);
    event TrancheUpdated(uint256 indexed trancheId);
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    function _charactersPlayed(uint256) external view returns (uint256);

    function _containedIn(uint256) external view returns (uint256);

    function _dependsOnCharacters(uint256) external view returns (uint256);

    function _dependsOnRoles(uint256) external view returns (uint256);

    function _holdingStrategies(uint256) external view returns (address);

    function _oracleCache(address, address) external view returns (address);

    function _rolesPlayed(uint256) external view returns (uint256);

    function _trancheDebt(uint256) external view returns (uint256);

    function approve(address to, uint256 tokenId) external;

    function assetConfigs(
        address
    )
        external
        view
        returns (uint256 debtCeiling, uint256 feePer10k, uint256 totalDebt);

    function balanceOf(address owner) external view returns (uint256);

    function batchCollectYield(
        uint256[] memory trancheIds,
        address currency,
        address recipient
    ) external returns (uint256);

    function batchCollectYieldValueBorrowable(
        uint256[] memory trancheIds,
        address yieldCurrency,
        address valueCurrency,
        address recipient
    ) external returns (uint256 yield, uint256 value, uint256 borrowablePer10k);

    function batchViewValueBorrowable(
        uint256[] memory trancheIds,
        address currency
    ) external view returns (uint256, uint256);

    function batchViewYield(
        uint256[] memory trancheIds,
        address currency
    ) external view returns (uint256);

    function charactersPlayed() external view returns (uint256[] memory);

    function collectYield(
        uint256 trancheId,
        address currency,
        address recipient
    ) external returns (uint256);

    function collectYieldValueBorrowable(
        uint256 trancheId,
        address yieldCurrency,
        address valueCurrency,
        address recipient
    ) external returns (uint256, uint256, uint256);

    function compoundLastUpdated() external view returns (uint256);

    function compoundPer1e18() external view returns (uint256);

    function compoundStart(uint256) external view returns (uint256);

    function compoundWindow() external view returns (uint256);

    function containedIn(
        uint256 tokenId
    ) external view returns (address owner, uint256 containerId);

    function dependsOnCharacters() external view returns (uint256[] memory);

    function dependsOnRoles() external view returns (uint256[] memory);

    function deposit(uint256 trancheId, uint256 tokenAmount) external;

    function depositAndBorrow(
        uint256 trancheId,
        uint256 collateralAmount,
        uint256 borrowAmount,
        address recipient
    ) external;

    function getApproved(uint256 tokenId) external view returns (address);

    function getCurrentHoldingStrategy(
        uint256 trancheId
    ) external returns (address);

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);

    function isAuthorized(
        address spender,
        uint256 tokenId
    ) external view returns (bool);

    function isViable(uint256 trancheId) external view returns (bool);

    function mainCharacterCache(uint256) external view returns (address);

    function migrateStrategy(
        uint256 trancheId,
        address destination,
        address yieldToken,
        address yieldRecipient
    ) external returns (address token, uint256 tokenId, uint256 targetAmount);

    function mintDepositAndBorrow(
        address collateralToken,
        address strategy,
        uint256 collateralAmount,
        uint256 borrowAmount,
        address stableRecipient
    ) external returns (uint256);

    function mintTranche(
        uint256 vaultId,
        address strategy,
        address assetToken,
        uint256 assetTokenId,
        uint256 assetAmount
    ) external returns (uint256 trancheId);

    function name() external view returns (string memory);

    function newCurrentOracle(address token, address pegCurrency) external;

    function ownerOf(uint256 tokenId) external view returns (address);

    function pastFees() external view returns (uint256);

    function pendingFees() external view returns (uint256);

    function registerDepositFor(
        address depositor,
        uint256 trancheId,
        uint256 tokenAmount
    ) external;

    function repay(uint256 trancheId, uint256 repayAmount) external;

    function repayAndWithdraw(
        uint256 trancheId,
        uint256 collateralAmount,
        uint256 repayAmount,
        address recipient
    ) external;

    function roleCache(address, uint256) external view returns (bool);

    function roles() external view returns (address);

    function rolesPlayed() external view returns (uint256[] memory);

    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (address, uint256);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) external;

    function setApprovalForAll(address operator, bool approved) external;

    function setAssetDebtCeiling(address token, uint256 ceiling) external;

    function setCompoundWindow(uint256 window) external;

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external;

    function setFeesPer10k(address token, uint256 fee) external;

    function setUpdateTrackingPeriod(uint256 period) external;

    function setupTrancheSlot() external;

    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    function symbol() external view returns (string memory);

    function tokenByIndex(uint256 index) external view returns (uint256);

    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) external view returns (uint256);

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function totalDebt() external view returns (uint256);

    function totalEarnedInterest() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function trancheDebt(uint256 trancheId) external view returns (uint256);

    function trancheToken(uint256 trancheId) external view returns (address);

    function transferFrom(address from, address to, uint256 tokenId) external;

    function updateMainCharacterCache(uint256 role) external;

    function updateRoleCache(uint256 role, address contr) external;

    function updateTrackingPeriod() external view returns (uint256);

    function viewAllFeesEver() external view returns (uint256);

    function viewBorrowable(uint256 trancheId) external view returns (uint256);

    function viewCollateralValue(
        uint256 trancheId,
        address valueCurrency
    ) external view returns (uint256);

    function viewCollateralValue(
        uint256 trancheId
    ) external view returns (uint256);

    function viewCurrentHoldingStrategy(
        uint256 trancheId
    ) external view returns (address);

    function viewILMetadata(
        address token
    ) external view returns (ILMetadata memory);

    function viewPositionMetadata(
        uint256 _trancheId
    ) external view returns (PositionMetadata memory);

    function viewPositionsByOwner(
        address owner
    ) external view returns (PositionMetadata[] memory);

    function viewPositionsByTrackingPeriod(
        uint256 trackingPeriod
    ) external view returns (PositionMetadata[] memory rows);

    function viewTargetCollateralAmount(
        uint256 trancheId
    ) external view returns (uint256);

    function viewTranchesByOwner(
        address owner
    ) external view returns (uint256[] memory);

    function viewUpdatedCompound() external view returns (uint256);

    function viewYield(
        uint256 trancheId,
        address currency
    ) external view returns (uint256);

    function viewYieldCollateralValueBorrowable(
        uint256 trancheId,
        address yieldCurrency,
        address valueCurrency
    ) external view returns (uint256, uint256, uint256);

    function viewYieldValueBorrowable(
        uint256 trancheId,
        address yieldCurrency,
        address valueCurrency
    ) external view returns (uint256, uint256, uint256);

    function withdraw(
        uint256 trancheId,
        uint256 tokenAmount,
        address yieldCurrency,
        address recipient
    ) external;

    function withdrawFees() external;
}
