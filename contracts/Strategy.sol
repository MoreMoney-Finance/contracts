// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../interfaces/IStrategy.sol";
import "./oracles/OracleAware.sol";
import "./Tranche.sol";
import "./roles/DependsOnStrategyRegistry.sol";
import "./roles/CallsStableCoinMintBurn.sol";
import "./roles/DependsOnTranche.sol";
import "./roles/DependsOnFundTransferer.sol";

abstract contract Strategy is
    IStrategy,
    OracleAware,
    CallsStableCoinMintBurn,
    DependsOnStrategyRegistry,
    DependsOnTranche,
    DependsOnFundTransferer,
    TrancheIDAware
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    bool public override isActive = true;

    bytes32 public immutable override strategyName;

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
        uint256 apfLastUpdated;
        uint256 apf;
    }

    uint256 public apfSmoothingPer10k = 5000;

    mapping(address => TokenMetadata) public tokenMetadata;

    uint256 internal constant FP64 = 2**64;

    constructor(bytes32 stratName) {
        strategyName = stratName;
    }

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
    ) internal virtual {
        address token = trancheToken(trancheId);
        _applyCompounding(trancheId);

        collectCollateral(depositor, token, amount);
        _accounts[trancheId].collateral += amount;
        tokenMetadata[token].totalCollateralNow += amount;
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
        // todo: should we collect yield here?
        _withdraw(trancheId, amount, recipient);
    }

    function _withdraw(
        uint256 trancheId,
        uint256 amount,
        address recipient
    ) internal virtual {
        address token = trancheToken(trancheId);
        _applyCompounding(trancheId);

        amount = min(amount, viewTargetCollateralAmount(trancheId));
        returnCollateral(recipient, token, amount);
        _accounts[trancheId].collateral -= amount;
        tokenMetadata[token].totalCollateralNow -= amount;
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

        _collectYield(trancheId, yieldToken, recipient);
        _withdraw(trancheId, viewTargetCollateralAmount(trancheId), recipient);
        delete _accounts[trancheId];
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

            uint256 totalAmount = _viewTVL(token);
            StrategyRegistry registry = strategyRegistry();
            returnCollateral(address(registry), token, totalAmount);
            IERC20(token).approve(address(registry), type(uint256).max);

            registry.migrateTokenTo(destination, token);
        }
        isActive = false;
    }

    function tallyHarvestBalance() internal virtual returns (uint256 balance) {}

    function collectYield(
        uint256 trancheId,
        address currency,
        address recipient
    ) public virtual override returns (uint256) {
        require(
            isFundTransferer(msg.sender) ||
                Tranche(tranche(trancheId)).isAuthorized(msg.sender, trancheId),
            "Not authorized to collect yield"
        );

        return _collectYield(trancheId, currency, recipient);
    }

    function collectYieldValueBorrowable(
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
            uint256 borrowablePer10k
        )
    {
        require(
            isFundTransferer(msg.sender) ||
                Tranche(tranche(trancheId)).isAuthorized(msg.sender, trancheId),
            "Not authorized to collect yield"
        );

        yield = _collectYield(trancheId, _yieldCurrency, recipient);
        (value, borrowablePer10k) = _getValueBorrowable(
            trancheToken(trancheId),
            viewTargetCollateralAmount(trancheId),
            valueCurrency
        );
    }

    function viewYieldValueBorrowable(
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
            uint256 borrowablePer10k
        )
    {
        yield = viewYield(trancheId, _yieldCurrency);
        (value, borrowablePer10k) = _viewValueBorrowable(
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
        (value, ) = _viewValueBorrowable(
            trancheToken(trancheId),
            viewTargetCollateralAmount(trancheId),
            valueCurrency
        );
    }

    function viewValueBorrowable(uint256 trancheId, address valueCurrency)
        external
        view
        override
        returns (uint256 value, uint256 borrowable)
    {
        return
            _viewValueBorrowable(
                trancheToken(trancheId),
                viewTargetCollateralAmount(trancheId),
                valueCurrency
            );
    }

    function viewBorrowable(uint256 trancheId)
        external
        view
        override
        returns (uint256 borrowablePer10k)
    {
        (, borrowablePer10k) = _viewValueBorrowable(
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

    function approvedToken(address token) public view override returns (bool) {
        return _approvedTokens.contains(token);
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
        return address(stableCoin());
    }

    function approveToken(address token, bytes calldata data)
        external
        virtual
        onlyOwnerExecActivator
    {
        _approveToken(token, data);
    }

    function _approveToken(address token, bytes calldata) internal virtual {
        _approvedTokens.add(token);
        _allTokensEver.add(token);

        strategyRegistry().updateTokenCount(address(this));
    }

    function disapproveToken(address token, bytes calldata)
        external
        virtual
        onlyOwnerExec
    {
        _approvedTokens.remove(token);
    }

    function viewTargetCollateralAmount(uint256 trancheId)
        public
        view
        virtual
        override
        returns (uint256)
    {
        CollateralAccount storage account = _accounts[trancheId];
        return account.collateral;
    }

    function trancheTokenID(uint256) external pure override returns (uint256) {
        return 0;
    }

    function viewAllTokensEver() external view returns (address[] memory) {
        return _allTokensEver.values();
    }

    function viewAllApprovedTokens()
        external
        view
        override
        returns (address[] memory)
    {
        return _approvedTokens.values();
    }

    function approvedTokensCount() external view override returns (uint256) {
        return _approvedTokens.length();
    }

    function viewStrategyMetadata(address token)
        public
        view
        override
        returns (IStrategy.StrategyMetadata memory)
    {
        (uint256 value, uint256 borrowablePer10k) = _viewValueBorrowable(
            token,
            1 ether,
            address(stableCoin())
        );

        return
            IStrategy.StrategyMetadata({
                strategy: address(this),
                token: token,
                APF: viewAPF(token),
                totalCollateral: tokenMetadata[token].totalCollateralNow,
                borrowablePer10k: borrowablePer10k,
                valuePer1e18: value,
                strategyName: strategyName,
                tvl: _viewTVL(token),
                harvestBalance2Tally: viewHarvestBalance2Tally(token),
                yieldType: yieldType(),
                stabilityFee: stabilityFeePer10k(token)
            });
    }

    function viewAllStrategyMetadata()
        external
        view
        override
        returns (IStrategy.StrategyMetadata[] memory)
    {
        uint256 tokenCount = _approvedTokens.length();
        IStrategy.StrategyMetadata[]
            memory result = new IStrategy.StrategyMetadata[](tokenCount);
        for (uint256 i; tokenCount > i; i++) {
            result[i] = viewStrategyMetadata(_approvedTokens.at(i));
        }
        return result;
    }

    function viewAPF(address) public view virtual override returns (uint256) {
        // TODO
        return 10_000;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return b;
        } else {
            return a;
        }
    }

    function _applyCompounding(uint256 trancheId) internal virtual {}

    function _viewTVL(address token) public view virtual returns (uint256) {
        return tokenMetadata[token].totalCollateralNow;
    }

    function stabilityFeePer10k(address) public view virtual returns (uint256) {
        return 0;
    }

    function _updateAPF(
        address token,
        uint256 addedBalance,
        uint256 basisValue
    ) internal {
        TokenMetadata storage tokenMeta = tokenMetadata[token];
        require(addedBalance > 0, "No balance to update APF");
        uint256 lastUpdated = tokenMeta.apfLastUpdated;
        uint256 timeDelta = lastUpdated > 0
            ? block.timestamp - lastUpdated
            : 1 weeks;

        uint256 newRate = ((addedBalance + basisValue) * 10_000 * (365 days)) /
            basisValue /
            timeDelta;

        uint256 smoothing = lastUpdated > 0 ? apfSmoothingPer10k : 0;
        tokenMeta.apf =
            (tokenMeta.apf * smoothing) /
            10_000 +
            (newRate * (10_000 - smoothing)) /
            10_000;
        tokenMeta.apfLastUpdated = block.timestamp;
    }

    function setApfSmoothingPer10k(uint256 smoothing) external onlyOwnerExec {
        apfSmoothingPer10k = smoothing;
    }

    function _updateAPF(
        uint256 timeDelta,
        address token,
        uint256 addedBalance,
        uint256 basisValue
    ) internal {
        TokenMetadata storage tokenMeta = tokenMetadata[token];
        require(addedBalance > 0, "No balance to update APF");

        uint256 lastUpdated = tokenMeta.apfLastUpdated;

        uint256 newRate = ((addedBalance + basisValue) * 10_000 * (365 days)) /
            basisValue /
            timeDelta;

        uint256 smoothing = lastUpdated > 0 ? apfSmoothingPer10k : 0;
        tokenMeta.apf =
            (tokenMeta.apf * smoothing) /
            10_000 +
            (newRate * (10_000 - smoothing)) /
            10_000;
        tokenMeta.apfLastUpdated = block.timestamp;
    }

    function viewHarvestBalance2Tally(address)
        public
        view
        virtual
        returns (uint256)
    {
        return 0;
    }

    function yieldType() public view virtual override returns (YieldType);
}
