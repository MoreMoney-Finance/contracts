// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./MultiYieldConversionStrategy.sol";
import "../../interfaces/IGmxRewardRouter.sol";

contract fsGLPStrategy is MultiYieldConversionStrategy {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;


    IERC20 public stakedGlp = IERC20(0x5643F4b25E36478eE1E90418d5343cb6591BcB9d);
    IGmxRewardRouter public rewardRouter = IGmxRewardRouter(0x82147C5A7E850eA4E28155DF107F2590fD4ba327);
    address public constant fsGlp = 0x9e295B5B976a184B14aD8cd72413aD846C299660;

    constructor(address _roles) Strategy("fsGLPSttrategy") TrancheIDAware(_roles) MultiYieldConversionStrategy(0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd) {
        rewardTokens[fsGlp].add(0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd);
        _approvedTokens.add(fsGlp);
    }

    function collectCollateral(address source, address token, uint256 amount) internal override {
        require(token == fsGlp, "Strategy only accepts fsGLP");
        stakedGlp.safeTransferFrom(source, address(this), amount);
    }

    function returnCollateral(address recipient, address token, uint256 amount) internal override returns (uint256) {
        require(token == fsGlp, "Strategy only handles fsGLP");
        stakedGlp.safeTransfer(recipient, amount);
        return amount;
    }

    function checkApprovedAndEncode(address token) public view returns (bool, bytes memory) {
        return (token == fsGlp, "");
    }

    function harvestPartially(address token) external override nonReentrant {
        require(token == fsGlp, "Strategy only handles fsGLP");
        rewardRouter.handleRewards(true, true, true, true, true, true, false);
        tallyReward(token);
    }

    /// View pending reward
    function viewSourceHarvestable(address)
        public
        view
        override
        returns (uint256)
    {
        return
            0;
            // _viewValue(
            //     rewardRouter.glp(),
            //     // pending amount here
            //     yieldCurrency()
            // );
    }

    // View the underlying yield strategy (if any)
    function viewUnderlyingStrategy(address)
        public
        view
        virtual
        override
        returns (address)
    {
        return address(rewardRouter);
    }

    // TODO setters
}