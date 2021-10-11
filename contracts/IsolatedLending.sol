// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./RoleAware.sol";
import "./Tranche.sol";
import "./Stablecoin.sol";

contract IsolatedLending is Tranche {
    struct AssetConfig {
        uint256 debtCeiling;
        uint256 feePerMil;
    }
    mapping(address => AssetConfig) public assetConfigs;

    mapping(uint256 => uint256) public trancheDebt;

    constructor(address _roles)
        Tranche("MoreMoney Isolated Lending", "MMIL", _roles)
    {}

    function setAssetDebtCeiling(address token, uint256 ceiling)
        external
        onlyOwnerExecDisabler
    {
        assetConfigs[token].debtCeiling = ceiling;
    }

    function setFeesPerMil(address token, uint256 fee) external onlyOwnerExec {
        assetConfigs[token].feePerMil = fee;
    }

    function mintDepositAndBorrow(
        address collateralToken,
        address strategy,
        uint256 collateralAmount,
        uint256 borrowAmount,
        address recipient
    ) external virtual returns (uint256) {
        uint256 trancheId = _mintTranche(
            msg.sender,
            0,
            strategy,
            collateralToken,
            0,
            collateralAmount
        );
        _borrow(trancheId, borrowAmount, recipient);
        return trancheId;
    }

    function depositAndBorrow(
        uint256 trancheId,
        uint256 collateralAmount,
        uint256 borrowAmount,
        address recipient
    ) external virtual {
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to withdraw yield"
        );

        _deposit(msg.sender, trancheId, collateralAmount);
        _borrow(trancheId, borrowAmount, recipient);
    }

    function _borrow(
        uint256 trancheId,
        uint256 borrowAmount,
        address recipient
    ) internal {
        if (borrowAmount > 0) {
            address holdingStrategy = getCurrentHoldingStrategy(trancheId);
            uint256 fee = mintingFee(
                borrowAmount,
                IStrategy(holdingStrategy).trancheToken(trancheId)
            );

            trancheDebt[trancheId] += borrowAmount + fee;

            uint256 excessYield = _yieldAndViability(trancheId);
            Stablecoin(stableCoin()).mint(
                recipient,
                borrowAmount + excessYield
            );
        }
    }

    function _yieldAndViability(uint256 trancheId)
        internal
        returns (uint256 excessYield)
    {
        uint256 debt = trancheDebt[trancheId];
        (
            uint256 yield,
            uint256 value,
            uint256 colRatio
        ) = _collectYieldValueColRatio(
                trancheId,
                stableCoin(),
                stableCoin(),
                address(this)
            );
        require(
            _isViable(debt, yield, value, colRatio),
            "Borow breaks min collateralization threshold"
        );

        if (yield > debt) {
            trancheDebt[trancheId] = 0;
            excessYield = yield - debt;
        } else {
            trancheDebt[trancheId] = debt - yield;
            excessYield = 0;
        }
        Stablecoin(stableCoin()).burn(address(this), yield);
    }

    function repayAndWithdraw(
        uint256 trancheId,
        uint256 collateralAmount,
        uint256 repayAmount,
        address recipient
    ) external virtual {
        require(
            isAuthorized(msg.sender, trancheId),
            "not authorized to withdraw yield"
        );

        _repay(msg.sender, trancheId, repayAmount);
        _withdraw(trancheId, collateralAmount, recipient);
    }

    function _withdraw(
        uint256 trancheId,
        uint256 tokenAmount,
        address recipient
    ) internal virtual override {
        if (tokenAmount > 0) {
            uint256 excessYield = _yieldAndViability(trancheId);
            if (excessYield > 0) {
                Stablecoin(stableCoin()).mint(recipient, excessYield);
            }
            super._withdraw(trancheId, tokenAmount, recipient);
        }
    }

    function _repay(
        address payer,
        uint256 trancheId,
        uint256 repayAmount
    ) internal virtual {
        if (repayAmount > 0) {
            Stablecoin(stableCoin()).burn(payer, repayAmount);
            trancheDebt[trancheId] -= repayAmount;
        }
    }

    function _checkAssetToken(address token) internal view virtual override {
        require(
            assetConfigs[token].debtCeiling > 0,
            "Token is not whitelisted"
        );
    }

    function _isViable(
        uint256 debt,
        uint256 yield,
        uint256 value,
        uint256 colRatio
    ) internal pure returns (bool) {
        return (value + yield) * 1000 >= debt * colRatio;
    }

    function isViable(uint256 trancheId)
        public
        view
        virtual
        override
        returns (bool)
    {
        (
            uint256 yield,
            uint256 value,
            uint256 colRatio
        ) = viewYieldValueColRatio(trancheId, stableCoin(), stableCoin());
        bool collateralized = _isViable(
            trancheDebt[trancheId],
            yield,
            value,
            colRatio
        );
        return collateralized && super.isViable(trancheId);
    }

    /// Minting fee per stable amount
    function mintingFee(uint256 stableAmount, address collateral)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 feePerMil = assetConfigs[collateral].feePerMil;
        if (feePerMil > 0) {
            return (feePerMil * stableAmount) / 1000;
        } else {
            return (assetConfigs[address(0)].feePerMil * stableAmount) / 1000;
        }
    }
}
