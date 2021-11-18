// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Strategy.sol";
import "../roles/DependsOnFeeRecipient.sol";

/// Do-nothing strategy
/// This is just intended for testing, not production at this time
contract SimpleHoldingStrategy is Strategy, DependsOnFeeRecipient {
    using SafeERC20 for IERC20;

    mapping(address => uint256) private _stabilityFeePer10k;
    mapping(uint256 => uint256) public depositTime;

    constructor(address _roles)
        Strategy("Simple holding strategy")
        TrancheIDAware(_roles)
    {}

    /// get that collateral
    function collectCollateral(
        address source,
        address token,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        IERC20(token).safeTransferFrom(source, address(this), collateralAmount);
        return collateralAmount;
    }

    /// give it back
    function returnCollateral(
        address recipient,
        address token,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        IERC20(token).safeTransfer(recipient, collateralAmount);
        return collateralAmount;
    }

    /// how much collateral does a tranche have
    function viewTargetCollateralAmount(uint256 trancheId)
        public
        view
        override
        returns (uint256)
    {
        CollateralAccount storage account = _accounts[trancheId];
        uint256 amount = account.collateral;
        uint256 delta = (amount *
            (block.timestamp - depositTime[trancheId]) *
            _stabilityFeePer10k[account.trancheToken]) /
            (365 days) /
            10_000;
        if (amount > delta) {
            return amount - delta;
        } else {
            return 0;
        }
    }

    /// If we need a stability fee we take it here
    function _applyCompounding(uint256 trancheId) internal virtual override {
        CollateralAccount storage account = _accounts[trancheId];
        if (account.collateral > 0) {
            address token = account.trancheToken;
            TokenMetadata storage tokenMeta = tokenMetadata[token];
            uint256 newAmount = viewTargetCollateralAmount(trancheId);
            uint256 oldAmount = account.collateral;

            if (oldAmount > newAmount) {
                returnCollateral(feeRecipient(), token, oldAmount - newAmount);

                tokenMeta.totalCollateralNow =
                    tokenMeta.totalCollateralNow +
                    newAmount -
                    oldAmount;
            }

            account.collateral = newAmount;
        }
        depositTime[trancheId] = block.timestamp;
    }

    /// Set stability fee, if any
    function setStabilityFeePer10k(address token, uint256 yearlyFeePer10k)
        external
        onlyOwnerExec
    {
        _stabilityFeePer10k[token] = yearlyFeePer10k;
    }

    /// Internal, approve token
    function _approveToken(address token, bytes calldata data)
        internal
        override
    {
        uint256 stabilityFee = abi.decode(data, (uint256));
        _stabilityFeePer10k[token] = stabilityFee;

        super._approveToken(token, data);
    }

    /// Initialize token
    function checkApprovedAndEncode(address token, uint256 stabilityFee)
        public
        view
        returns (bool, bytes memory)
    {
        return (approvedToken(token), abi.encode(stabilityFee));
    }

    /// Here we do no yield
    function yieldType() public pure override returns (IStrategy.YieldType) {
        return IStrategy.YieldType.NOYIELD;
    }

    /// Stability fee if any
    function stabilityFeePer10k(address token)
        public
        view
        override
        returns (uint256)
    {
        return _stabilityFeePer10k[token];
    }

    function harvestPartially(address token) external override {}
}
