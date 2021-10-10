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

    uint256 public totalCollateralPast;
    uint256 public totalCollateralNow;
    uint256 internal constant FP64 = 2**64;

    function deposit(uint256 trancheId, uint256 amount) external override {
        _deposit(msg.sender, trancheId, amount);
    }

    function registerDepositFor(
        address depositor,
        uint256 trancheId,
        uint256 amount
    ) external {
        require(
            isFundTransferer(msg.sender),
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
        address recipient,
        uint256 amount
    ) external {
        require(
            Tranche(tranche()).isAuthorized(msg.sender, trancheId),
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
}
