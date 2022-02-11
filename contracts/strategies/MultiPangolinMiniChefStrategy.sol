// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/IMasterChefJoeV2.sol";
import "./MultiMasterChefStrategy.sol";

/// Use MiniChef pangolin
contract MultiPangolinMiniChefStrategy is MultiMasterChefStrategy {
    constructor(address _wrappedNative, address _roles)
        MultiMasterChefStrategy(
            "Pangolin self-repaying",
            0x1f806f7C8dED893fd3caE279191ad7Aa3798E928,
            0x60781C2586D68229fde47564546784ab3fACA982,
            _wrappedNative,
            _roles
        )
    {}

    /// Annual percentage factor, APR = APF - 100%
    function viewAPF(address token)
        public
        view
        virtual
        override
        returns (uint256)
    {
        address stable = address(yieldCurrency());
        uint256 perSecValue = _viewValue(
            mainRewardToken,
            chef.joePerSec(),
            stable
        );
        uint256 stakedValue = _viewValue(
            token,
            IERC20(token).balanceOf(address(chef)),
            stable
        );
        uint256 points = IMasterChefJoeV2(address(chef))
            .poolInfo(pids[token])
            .allocPoint;
        return
            10_000 +
            ((10_000 - feePer10k) * (365 days) * perSecValue * points) /
            chef.totalAllocPoint() /
            stakedValue;
    }
}
