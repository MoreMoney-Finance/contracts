// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/IStrategy.sol";
import "./oracles/OracleAware.sol";
import "./Tranche.sol";
import "./roles/DependsOnStrategyRegistry.sol";
import "./roles/CallsStableCoinMintBurn.sol";
import "./roles/DependsOnTranche.sol";
import "./roles/DependsOnFundTransferer.sol";

/// Base class for strategies with facilities to manage (deposit/withdraw)
/// collateral in yield bearing system as well as yield distribution
abstract contract Strategy is
    IStrategy,
    OracleAware,
    CallsStableCoinMintBurn,
    DependsOnStrategyRegistry,
    DependsOnTranche,
    DependsOnFundTransferer,
    TrancheIDAware,
    ReentrancyGuard
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
        uint256 totalCollateralThisPhase;
        uint256 totalCollateralNow;
        uint256 apfLastUpdated;
        uint256 apf;
        uint256 depositLimit;
    }

    uint256 public apfSmoothingPer10k = 5000;

    mapping(address => TokenMetadata) public tokenMetadata;

    uint256 internal constant FP64 = 2**64;

    constructor(bytes32 stratName) {
        strategyName = stratName;
    }

    /// Run only if the strategy has not been deactivated
    modifier onlyActive() {
        require(isActive, "Strategy is not active");
        _;
    }

    /// Allows tranche contracts to register new tranches
    function registerMintTranche(
        address minter,
        uint256 trancheId,
        address assetToken,
        uint256,
        uint256 assetAmount
    ) external override onlyActive nonReentrant {
        require(
            isFundTransferer(msg.sender) && tranche(trancheId) == msg.sender,
            "Invalid tranche"
        );
        _mintTranche(minter, trancheId, assetToken, assetAmount);
    }

    /// Internals for minting or migrating a tranche
    function _mintTranche(
        address minter,
        uint256 trancheId,
        address assetToken,
        uint256 assetAmount
    ) internal {
        TokenMetadata storage meta = tokenMetadata[assetToken];
        _accounts[trancheId].yieldCheckptIdx = meta.yieldCheckpoints.length;
        _setAndCheckTrancheToken(trancheId, assetToken);
        _deposit(minter, trancheId, assetAmount, yieldCurrency(), minter);
    }

    /// Register deposit to tranche on behalf of user (to be called by other contract)
    function registerDepositFor(
        address depositor,
        uint256 trancheId,
        uint256 amount,
        address yieldRecipient
    ) external virtual override onlyActive nonReentrant {
        require(
            isFundTransferer(msg.sender),
            "Not authorized to transfer user funds"
        );
        _deposit(depositor, trancheId, amount, yieldCurrency(), yieldRecipient);
    }

    /// Internal function to manage depositing
    function _deposit(
        address depositor,
        uint256 trancheId,
        uint256 amount,
        address yieldToken,
        address yieldRecipient
    ) internal virtual {
        address token = trancheToken(trancheId);
        _collectYield(trancheId, yieldToken, yieldRecipient);

        collectCollateral(depositor, token, amount);
        uint256 oldBalance = _accounts[trancheId].collateral;
        _accounts[trancheId].collateral = oldBalance + amount;

        TokenMetadata storage meta = tokenMetadata[token];
        meta.totalCollateralNow += amount;
        _handleBalanceUpdate(trancheId, token, oldBalance + amount);

        require(meta.depositLimit > _viewTVL(token), "Exceeding deposit limit");
    }

    /// Callback for strategy-specific logic
    function _handleBalanceUpdate(
        uint256 trancheId,
        address token,
        uint256 balance
    ) internal virtual {}

    /// Withdraw tokens from tranche (only callable by fund transferer)
    function withdraw(
        uint256 trancheId,
        uint256 amount,
        address yieldToken,
        address recipient
    ) external virtual override onlyActive nonReentrant {
        require(isFundTransferer(msg.sender), "Not authorized to withdraw");
        require(recipient != address(0), "Don't send to zero address");

        _withdraw(trancheId, amount, yieldToken, recipient);
    }

    /// Internal machinations of withdrawals and returning collateral
    function _withdraw(
        uint256 trancheId,
        uint256 amount,
        address yieldToken,
        address recipient
    ) internal virtual {
        CollateralAccount storage account = _accounts[trancheId];
        address token = trancheToken(trancheId);

        _collectYield(trancheId, yieldToken, recipient);

        amount = min(amount, viewTargetCollateralAmount(trancheId));
        returnCollateral(recipient, token, amount);

        account.collateral -= amount;

        TokenMetadata storage meta = tokenMetadata[token];
        // compounding strategies must add any additional collateral to totalCollateralNow
        // in _collectYield, so we don't get an underflow here
        meta.totalCollateralNow -= amount;

        if (meta.yieldCheckpoints.length > account.yieldCheckptIdx) {
            // this account is participating in the current distribution phase, remove it
            meta.totalCollateralThisPhase -= amount;
        }
    }

    /// Migrate contents of tranche to new strategy
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

    /// Accept migrated assets from another tranche
    function acceptMigration(
        uint256 trancheId,
        address sourceStrategy,
        address tokenContract,
        uint256,
        uint256 amount
    ) external virtual override nonReentrant {
        require(msg.sender == tranche(trancheId), "Not authorized to migrate");
        _mintTranche(sourceStrategy, trancheId, tokenContract, amount);
    }

    /// Migrate all tranches managed to a new strategy, using strategy registry as
    /// go-between
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

            registry.depositMigrationTokens(destination, token);
        }
        isActive = false;
    }

    /// Account for harvested yield which has lapped up upon the shore of this
    /// contract's balance and convert it into yield for users, for all tokens
    function tallyHarvestBalance() internal virtual returns (uint256 balance) {}

    function collectYield(
        uint256 trancheId,
        address currency,
        address recipient
    ) external virtual override nonReentrant returns (uint256) {
        require(
            isFundTransferer(msg.sender) ||
                Tranche(tranche(trancheId)).isAuthorized(msg.sender, trancheId),
            "Not authorized to collect yield"
        );

        return _collectYield(trancheId, currency, recipient);
    }

    /// For a specific tranche, collect yield and view value and borrowable per 10k
    function collectYieldValueBorrowable(
        uint256 trancheId,
        address _yieldCurrency,
        address valueCurrency,
        address recipient
    )
        external
        override
        nonReentrant
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

    /// For a specific tranche, view its accrued yield, value and borrowable per 10k
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

    /// View the value of a tranche
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

    /// View value and borrowable per10k of tranche
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

    /// View borrowable per10k of tranche
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
    ) internal virtual;

    /// Return collateral to user
    function returnCollateral(
        address recipient,
        address token,
        uint256 collateralAmount
    ) internal virtual returns (uint256 collteral2Subtract);

    /// Returns the token associated with a tranche
    function trancheToken(uint256 trancheId)
        public
        view
        virtual
        override
        returns (address token)
    {
        return _accounts[trancheId].trancheToken;
    }

    /// Internal, sets the tranche token and checks that it's supported
    function _setAndCheckTrancheToken(uint256 trancheId, address token)
        internal
        virtual
    {
        require(_approvedTokens.contains(token), "Not an approved token");
        _accounts[trancheId].trancheToken = token;
    }

    /// Is a token supported by this strategy?
    function approvedToken(address token) public view override returns (bool) {
        return _approvedTokens.contains(token);
    }

    /// Internal, collect yield and disburse it to recipient
    function _collectYield(
        uint256 trancheId,
        address currency,
        address recipient
    ) internal virtual returns (uint256 yieldEarned);

    /// Internal, view accrued yield for account
    function _viewYield(
        CollateralAccount storage account,
        TokenMetadata storage tokenMeta,
        address currency
    ) internal view returns (uint256) {
        require(currency == yieldCurrency(), "Wrong yield currency");

        uint256[] storage checkPts = tokenMeta.yieldCheckpoints;
        if (checkPts.length > account.yieldCheckptIdx) {
            uint256 yieldDelta = checkPts[checkPts.length - 1] -
                checkPts[account.yieldCheckptIdx];
            return (account.collateral * yieldDelta) / FP64;
        } else {
            return 0;
        }
    }

    /// View accrued yield for a tranche
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

    /// The currency used to aggregate yield in this strategy (mintable)
    function yieldCurrency() public view virtual override returns (address) {
        return address(stableCoin());
    }

    /// set up a token to be supported by this strategy
    function approveToken(
        address token,
        uint256 depositLimit,
        bytes calldata data
    ) external virtual onlyOwnerExecActivator {
        tokenMetadata[token].depositLimit = depositLimit;
        _approveToken(token, data);

        // Kick the oracle to update
        _getValue(token, 1e18, address(stableCoin()));
    }

    /// Internals to approving token and informing the strategy registry
    function _approveToken(address token, bytes calldata) internal virtual {
        _approvedTokens.add(token);
        _allTokensEver.add(token);
        tokenMetadata[token].apf = 10_000;
        tokenMetadata[token].apfLastUpdated = block.timestamp;

        strategyRegistry().updateTokenCount(address(this));
    }

    /// Give some token the stink-eye and tell it to never show its face again
    function disapproveToken(address token, bytes calldata)
        external
        virtual
        onlyOwnerExec
    {
        _approvedTokens.remove(token);
        strategyRegistry().updateTokenCount(address(this));
    }

    /// Calculate collateral amount held by tranche (e.g. taking into account
    /// compounding)
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

    /// The ID of the tranche token (relevant if not handling ERC20)
    function trancheTokenID(uint256) external pure override returns (uint256) {
        return 0;
    }

    /// All the tokens this strategy has ever touched
    function viewAllTokensEver() external view returns (address[] memory) {
        return _allTokensEver.values();
    }

    /// View all tokens currently supported by this strategy
    function viewAllApprovedTokens()
        external
        view
        override
        returns (address[] memory)
    {
        return _approvedTokens.values();
    }

    /// count the number of tokens this strategy currently supports
    function approvedTokensCount() external view override returns (uint256) {
        return _approvedTokens.length();
    }

    /// View metadata for a token
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

    /// view metadata for all tokens in an array
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

    /// Annual percentage factor, APR = APF - 100%
    function viewAPF(address token)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return tokenMetadata[token].apf;
    }

    /// Miniumum of two numbes
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return b;
        } else {
            return a;
        }
    }

    /// View TVL in a token
    function _viewTVL(address token) public view virtual returns (uint256) {
        return tokenMetadata[token].totalCollateralNow;
    }

    /// View Stability fee if any
    function stabilityFeePer10k(address) public view virtual returns (uint256) {
        return 0;
    }

    /// Internal, update APF number
    function _updateAPF(
        address token,
        uint256 addedBalance,
        uint256 basisValue
    ) internal {
        TokenMetadata storage tokenMeta = tokenMetadata[token];
        if (addedBalance > 0) {
            uint256 lastUpdated = tokenMeta.apfLastUpdated;
            uint256 timeDelta = lastUpdated > 0
                ? block.timestamp - lastUpdated
                : 1 weeks;

            uint256 newRate = ((addedBalance + basisValue) *
                10_000 *
                (365 days)) /
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
    }

    /// Since return rates vary, we smooth
    function setApfSmoothingPer10k(uint256 smoothing) external onlyOwnerExec {
        apfSmoothingPer10k = smoothing;
    }

    /// View outstanding yield that needs to be distributed to accounts of an asset
    /// if any
    function viewHarvestBalance2Tally(address)
        public
        view
        virtual
        returns (uint256)
    {
        return 0;
    }

    /// Returns whether the strategy is compounding repaying or no yield
    function yieldType() public view virtual override returns (YieldType);

    /// In an emergency, withdraw tokens from yield generator
    function rescueCollateral(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwnerExec {
        require(recipient != address(0), "Don't send to zero address");
        returnCollateral(recipient, token, amount);
    }

    /// In an emergency, withdraw any tokens stranded in this contract's balance
    function rescueStrandedTokens(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwnerExec {
        require(recipient != address(0), "Don't send to zero address");
        IERC20(token).safeTransfer(recipient, amount);
    }

    /// Rescue any stranded native currency
    function rescueNative(uint256 amount, address recipient)
        external
        onlyOwnerExec
    {
        require(recipient != address(0), "Don't send to zero address");
        payable(recipient).transfer(amount);
    }

    /// Accept native deposits
    fallback() external payable {}

    receive() external payable {}

    /// Set the deposit limit for a token
    function setDepositLimit(address token, uint256 limit)
        external
        onlyOwnerExec
    {
        tokenMetadata[token].depositLimit = limit;
    }
}
