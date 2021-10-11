// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IStrategy.sol";
import "./RoleAware.sol";
import "./Tranche.sol";

abstract contract Strategy is IStrategy, RoleAware {
    using SafeERC20 for IERC20;

    bool public override isActive;

    struct CollateralAccount {
        uint256 collateral;
        uint256 yieldCheckptIdx;
    }

    mapping(uint256 => CollateralAccount) public _accounts;

    uint256[] public yieldCheckpoints;
    uint256 public cumulYieldPerCollateralFP;

    uint256 public totalCollateralNow;
    uint256 internal constant FP64 = 2**64;

    function registerMintTranche(
        address minter,
        uint256 trancheId,
        address assetToken,
        uint256,
        uint256 assetAmount
    ) external override {
        require(isTranche(msg.sender) && tranche(trancheId) == msg.sender,
        "Invalid tranche");

        _accounts[trancheId].yieldCheckptIdx = yieldCheckpoints.length;
        _setAndCheckTrancheToken(trancheId, assetToken);
        _deposit(minter, trancheId, assetAmount);
    }

    function deposit(uint256 trancheId, uint256 amount) external override {
        _deposit(msg.sender, trancheId, amount);
    }

    function registerDepositFor(
        address depositor,
        uint256 trancheId,
        uint256 amount
    ) external override {
        require(
            isTranche(msg.sender) || isFundTransferer(msg.sender),
            "Not authorized to transfer user funds"
        );
        _deposit(depositor, trancheId, amount);
    }

    function _deposit(
        address depositor,
        uint256 trancheId,
        uint256 amount
    ) internal {
        uint256 addCollateral = collectCollateral(
            depositor,
            trancheToken(trancheId),
            amount
        );
        _accounts[trancheId].collateral += addCollateral;
        totalCollateralNow += addCollateral;
    }

    function withdraw(
        uint256 trancheId,
        uint256 amount,
        address recipient
    ) external override {
        require(
            isFundTransferer(msg.sender) ||
            Tranche(tranche(trancheId)).isAuthorized(msg.sender, trancheId),
            "Not authorized to withdraw"
        );
        uint256 subCollateral = returnCollateral(
            recipient,
            trancheToken(trancheId),
            amount
        );
        _accounts[trancheId].collateral -= subCollateral;
        totalCollateralNow -= subCollateral;
    }

    function burnTranche(
        uint256 trancheId,
        address yieldToken,
        address recipient
    ) external override {
        require(
            isFundTransferer(msg.sender) ||
            Tranche(tranche(trancheId)).isAuthorized(msg.sender, trancheId),
            "Not authorized to burn tranche"
        );
        address token = trancheToken(trancheId);
        uint256 subCollateral = returnCollateral(
            recipient,
            token,
            viewTargetCollateralAmount(trancheId)
        );

        _collectYield(trancheId, yieldToken, recipient);
        delete _accounts[trancheId];
        totalCollateralNow -= subCollateral;
    }

    function migrateStrategy(
        uint256 trancheId,
        address targetStrategy,
        address yieldToken,
        address yieldRecipient
    )
        external
        override
        returns (
            address,
            uint256,
            uint256
        )
    {
        require(msg.sender == tranche(trancheId), "Not authorized to migrate");

        address token = trancheToken(trancheId);
        uint256 targetAmount = viewTargetCollateralAmount(trancheId);
        IERC20(token).approve(targetStrategy, targetAmount);
        _collectYield(trancheId, yieldToken, yieldRecipient);

        return (token, 0, targetAmount);
    }

    function acceptMigration(
        uint256 trancheId,
        address sourceStrategy,
        address tokenContract,
        uint256,
        uint256 amount
    ) external override {
        require(msg.sender == tranche(trancheId), "Not authorized to migrate");

        _setAndCheckTrancheToken(trancheId, tokenContract);
        _deposit(sourceStrategy, trancheId, amount);
    }

    /// Withdraw collateral from source account
    function collectCollateral(
        address source,
        address token,
        uint256 collateralAmount
    ) internal virtual returns (uint256 collateral2Add);

    /// Return collateral to user
    function returnCollateral(
        address recipient,
        address token,
        uint256 collateralAmount
    ) internal virtual returns (uint256 collteral2Subtract);

    function trancheToken(uint256 trancheId)
        public
        view
        virtual
        override
        returns (address token);

    function viewTargetCollateralAmount(uint256 trancheId)
        public
        view
        virtual
        override
        returns (uint256);

    function _setAndCheckTrancheToken(uint256 trancheId, address token)
        internal
        virtual;

    function _collectYield(
        uint256 trancheId,
        address token,
        address recipient
    ) internal virtual;

    function tranche(uint256 trancheId) public virtual returns (address);
}
