// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IMasterChefJoeV2.sol";
import "./MultiMasterChefStrategy.sol";

contract MultiTraderJoeMasterChef3Strategy is MultiMasterChefStrategy {
    constructor(address _wrappedNative, address _roles)
        MultiMasterChefStrategy(
            "Trader Joe self-repaying",
            0x188bED1968b795d5c9022F6a0bb5931Ac4c18F00,
            0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd,
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
