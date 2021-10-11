// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../interfaces/IStrategy.sol";
import "./OracleAware.sol";
import "./Tranche.sol";
import "./Stablecoin.sol";

abstract contract Strategy is IStrategy, OracleAware {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    bool public override isActive = true;

    EnumerableSet.AddressSet _approvedTokens;
    EnumerableSet.AddressSet _allTokensEver;

    struct CollateralAccount {
        uint256 collateral;
        uint256 yieldCheckptIdx;
        address trancheToken;
    }

    mapping(uint256 => CollateralAccount) public _accounts;

    struct TokenMetadata {
        uint256[] yieldCheckpoints;
        uint256 cumulYieldPerCollateralFP;
        uint256 totalCollateralPast;
        uint256 totalCollateralNow;
    }

    mapping(address => TokenMetadata) public tokenMetadata;

    uint256 internal constant FP64 = 2**64;

    modifier onlyActive() {
        require(isActive, "Strategy is not active");
        _;
    }

    function registerMintTranche(
        address minter,
        uint256 trancheId,
        address assetToken,
        uint256,
        uint256 assetAmount
    ) external override onlyActive {
        require(
            isTranche(msg.sender) && tranche(trancheId) == msg.sender,
            "Invalid tranche"
        );

        _accounts[trancheId].yieldCheckptIdx = tokenMetadata[assetToken]
            .yieldCheckpoints
            .length;
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
    ) external virtual override onlyActive {
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
        address token = trancheToken(trancheId);
        uint256 addCollateral = collectCollateral(depositor, token, amount);
        _accounts[trancheId].collateral += addCollateral;
        tokenMetadata[token].totalCollateralNow += addCollateral;
    }

    function withdraw(
        uint256 trancheId,
        uint256 amount,
        address recipient
    ) external virtual override onlyActive {
        require(
            isFundTransferer(msg.sender) ||
                Tranche(tranche(trancheId)).isAuthorized(msg.sender, trancheId),
            "Not authorized to withdraw"
        );
        address token = trancheToken(trancheId);
        uint256 subCollateral = returnCollateral(recipient, token, amount);
        _accounts[trancheId].collateral -= subCollateral;
        tokenMetadata[token].totalCollateralNow -= subCollateral;
    }

    function burnTranche(
        uint256 trancheId,
        address yieldToken,
        address recipient
    ) external virtual override onlyActive {
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
        tokenMetadata[token].totalCollateralNow -= subCollateral;
    }

    function migrateStrategy(
        uint256 trancheId,
        address targetStrategy,
        address yieldToken,
        address yieldRecipient
    )
        external
        virtual
        override
        onlyActive
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
        uint256 subCollateral = returnCollateral(
            address(this),
            token,
            targetAmount
        );
        tokenMetadata[token].totalCollateralNow -= subCollateral;

        return (token, 0, targetAmount);
    }

    function acceptMigration(
        uint256 trancheId,
        address sourceStrategy,
        address tokenContract,
        uint256,
        uint256 amount
    ) external virtual override {
        require(msg.sender == tranche(trancheId), "Not authorized to migrate");

        _setAndCheckTrancheToken(trancheId, tokenContract);
        _deposit(sourceStrategy, trancheId, amount);
    }

    function migrateAllTo(address destination)
        external
        override
        onlyActive
        onlyOwnerExecDisabler
    {
        tallyHarvestBalance();

        for (uint256 i; _allTokensEver.length() > i; i++) {
            address token = _allTokensEver.at(i);
            TokenMetadata storage tokenMeta = tokenMetadata[token];
            uint256 totalAmount = _viewTargetCollateralAmount(
                tokenMeta.totalCollateralNow,
                token
            );
            returnCollateral(strategyRegistry(), token, totalAmount);
            IERC20(token).approve(strategyRegistry(), type(uint256).max);

            StrategyRegistry(strategyRegistry()).migrateTokenTo(
                destination,
                token
            );
        }
        isActive = false;
    }

    function collectYield(
        uint256 trancheId,
        address currency,
        address recipient
    ) public virtual override returns (uint256) {
        require(
            isFundTransferer(msg.sender) ||
                Tranche(tranche(trancheId)).isAuthorized(msg.sender, trancheId),
            "Not authorized to burn tranche"
        );

        return _collectYield(trancheId, currency, recipient);
    }

    function collectYieldValueColRatio(
        uint256 trancheId,
        address _yieldCurrency,
        address valueCurrency,
        address recipient
    )
        external
        override
        returns (
            uint256 yield,
            uint256 value,
            uint256 colRatio
        )
    {
        yield = collectYield(trancheId, _yieldCurrency, recipient);
        (value, colRatio) = _getValueColRatio(
            trancheToken(trancheId),
            viewTargetCollateralAmount(trancheId),
            valueCurrency
        );
    }

    function viewYieldValueColRatio(
        uint256 trancheId,
        address _yieldCurrency,
        address valueCurrency
    )
        external
        view
        override
        returns (
            uint256 yield,
            uint256 value,
            uint256 colRatio
        )
    {
        yield = viewYield(trancheId, _yieldCurrency);
        (value, colRatio) = _viewValueColRatio(
            trancheToken(trancheId),
            viewTargetCollateralAmount(trancheId),
            valueCurrency
        );
    }

    function viewValue(uint256 trancheId, address valueCurrency)
        external
        view
        override
        returns (uint256 value)
    {
        (value, ) = _viewValueColRatio(
            trancheToken(trancheId),
            viewTargetCollateralAmount(trancheId),
            valueCurrency
        );
    }

    function viewColRatioTargetPer10k(uint256 trancheId)
        external
        view
        override
        returns (uint256 colRatio)
    {
        (, colRatio) = _viewValueColRatio(
            trancheToken(trancheId),
            viewTargetCollateralAmount(trancheId),
            yieldCurrency()
        );
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
        returns (address token)
    {
        return _accounts[trancheId].trancheToken;
    }

    function _setAndCheckTrancheToken(uint256 trancheId, address token)
        internal
        virtual
    {
        require(_approvedTokens.contains(token), "Not an approved token");
        _accounts[trancheId].trancheToken = token;
    }

    function _collectYield(
        uint256 trancheId,
        address currency,
        address recipient
    ) internal virtual returns (uint256 yieldEarned) {
        CollateralAccount storage account = _accounts[trancheId];
        TokenMetadata storage tokenMeta = tokenMetadata[
            trancheToken(trancheId)
        ];
        if (account.collateral > 0) {
            yieldEarned = _viewYield(account, tokenMeta, currency);
            Stablecoin(yieldCurrency()).mint(recipient, yieldEarned);
        }

        account.yieldCheckptIdx = tokenMeta.yieldCheckpoints.length;
    }

    function _viewYield(
        CollateralAccount storage account,
        TokenMetadata storage tokenMeta,
        address currency
    ) internal view returns (uint256) {
        require(currency == yieldCurrency(), "Wrong yield currency");
        if (tokenMeta.yieldCheckpoints.length > account.yieldCheckptIdx) {
            uint256 yieldDelta = tokenMeta.cumulYieldPerCollateralFP -
                tokenMeta.yieldCheckpoints[account.yieldCheckptIdx];
            return (account.collateral * yieldDelta) / FP64;
        } else {
            return 0;
        }
    }

    function viewYield(uint256 trancheId, address currency)
        public
        view
        virtual
        override
        returns (uint256)
    {
        CollateralAccount storage account = _accounts[trancheId];
        return
            _viewYield(
                account,
                tokenMetadata[trancheToken(trancheId)],
                currency
            );
    }

    function yieldCurrency() public view virtual returns (address) {
        return stableCoin();
    }

    /// roll over stable balance into yield to accounts
    /// (requires additional access controls if involved in a bidding system)
    function tallyHarvestBalance() internal virtual returns (uint256 balance) {
        Stablecoin stable = Stablecoin(yieldCurrency());
        balance = stable.balanceOf(address(this));
        if (balance > 0) {
            stable.burn(address(this), balance);

            for (uint256 i; _allTokensEver.length() > i; i++) {
                address token = _allTokensEver.at(i);
                TokenMetadata storage tokenMeta = tokenMetadata[token];
                tokenMeta.cumulYieldPerCollateralFP +=
                    (balance * FP64) /
                    tokenMeta.totalCollateralPast;
                tokenMeta.yieldCheckpoints.push(
                    tokenMeta.cumulYieldPerCollateralFP
                );
                tokenMeta.totalCollateralPast = tokenMeta.totalCollateralNow;
            }
        }
    }

    function approveToken(address token) external virtual onlyOwnerExec {
        _approvedTokens.add(token);
        _allTokensEver.add(token);
    }

    function disapproveToken(address token) external virtual onlyOwnerExec {
        _approvedTokens.remove(token);
    }

    function _viewTargetCollateralAmount(
        uint256 collateralAmount,
        address token
    ) internal view virtual returns (uint256);

    function viewTargetCollateralAmount(uint256 trancheId)
        public
        view
        override
        returns (uint256)
    {
        CollateralAccount storage account = _accounts[trancheId];
        return
            _viewTargetCollateralAmount(
                account.collateral,
                account.trancheToken
            );
    }

    function trancheTokenID(uint256)
        external
        pure
        override
        returns (uint256)
    {
        return 0;
    }
}
