// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Strategy.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract YieldConversionBidStrategy is Strategy {
    using SafeERC20 for IERC20;
    using SafeERC20 for Stablecoin;

    IERC20 public immutable rewardToken;

    event ConversionBid(uint256 conversionAmount, uint256 usdmBid);
    uint256 public conversionBidWindow = 60 minutes;

    address public pendingBidder;
    uint256 public pendingBidConversionAmount;
    uint256 public pendingBidUsdm;
    uint256 public pendingBidTime;

    constructor(address _rewardToken) {
        rewardToken = IERC20(_rewardToken);
    }

    function convertRewardBid(uint256 conversionAmount, uint256 usdmBid)
        external
    {
        if (conversionBidWindow + pendingBidTime >= block.timestamp) {
            // require to bid a better price and at least half the volume
            require(
                (usdmBid * 1e18) / conversionAmount >
                    (pendingBidUsdm * 1e18) / pendingBidConversionAmount &&
                    2 > pendingBidConversionAmount / conversionAmount,
                "Insufficient bid"
            );

            // return to previous bidder
            stableCoin().safeTransfer(pendingBidder, pendingBidUsdm);
        } else {
            returnOnBid();
        }

        pendingBidConversionAmount = min(
            rewardToken.balanceOf(address(this)),
            conversionAmount
        );
        pendingBidUsdm =
            (pendingBidConversionAmount * usdmBid) /
            conversionAmount;
        pendingBidTime = block.timestamp;
        pendingBidder = msg.sender;

        stableCoin().safeTransferFrom(
            msg.sender,
            address(this),
            pendingBidUsdm
        );

        emit ConversionBid(pendingBidConversionAmount, pendingBidUsdm);
    }

    function tallyHarvest() public {
        require(
            block.timestamp > conversionBidWindow + pendingBidTime,
            "Conversion bid still pending"
        );
        tallyHarvestBalance();
    }

    function returnOnBid() public {
        require(
            block.timestamp > conversionBidWindow + pendingBidTime,
            "Try back later"
        );
        if (pendingBidder != address(0)) {
            // idempotently disburse
            rewardToken.safeTransfer(pendingBidder, pendingBidConversionAmount);
            pendingBidder = address(0);
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return b;
        } else {
            return a;
        }
    }

    function setConversionBidWindow(uint256 window) external onlyOwnerExec {
        conversionBidWindow = window;
    }
}
