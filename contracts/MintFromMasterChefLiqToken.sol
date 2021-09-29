// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./MintFromLiqToken.sol";
import "../interfaces/IMasterChef.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MintFromMasterChefLiqToken is MintFromLiqToken {
    using SafeERC20 for IERC20;
    using SafeERC20 for Stablecoin;

    uint256 mintingFeePermil = 5;
    IMasterChef public immutable chef;
    uint256 public immutable pid;
    IERC20 public immutable rewardToken;

    event ConversionBid(uint256 conversionAmount, uint256 usdmBid);
    uint256 public conversionBidWindow;

    address public pendingBidder;
    uint256 public pendingBidConversionAmount;
    uint256 public pendingBidUsdm;
    uint256 public pendingBidTime;

    constructor(
        address _ammPair,
        address _oracleForToken0,
        address _oracleForToken1,
        uint256 _reservePermil,
        address _chef,
        uint256 _pid,
        address _rewardToken,
        uint256 _conversionBidWindow,
        address _roles
    )
        MintFromLiqToken(
            _ammPair,
            _oracleForToken0,
            _oracleForToken1,
            _reservePermil,
            _roles
        )
    {
        chef = IMasterChef(_chef);
        pid = _pid;
        rewardToken = IERC20(_rewardToken);
        conversionBidWindow = _conversionBidWindow;
    }

    function collectCollateral(address source, uint256 collateralAmount)
        internal
        override
    {
        IERC20(address(ammPair)).safeTransferFrom(
            source,
            address(this),
            collateralAmount
        );
        ammPair.approve(address(chef), collateralAmount);
        chef.deposit(pid, collateralAmount);
    }

    function returnCollateral(address recipient, uint256 collateralAmount)
        internal
        override
    {
        chef.withdraw(pid, collateralAmount);
        IERC20(address(ammPair)).safeTransfer(recipient, collateralAmount);
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
            Stablecoin(stableCoin()).safeTransfer(
                pendingBidder,
                pendingBidUsdm
            );
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

        Stablecoin(stableCoin()).safeTransferFrom(
            msg.sender,
            address(this),
            pendingBidUsdm
        );

        emit ConversionBid(pendingBidConversionAmount, pendingBidUsdm);
    }

    function tallyHarvest() public {
        require(block.timestamp > conversionBidWindow + pendingBidTime, "Conversion bid still pending");
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

    function mintingFee(uint256 stableAmount)
        public
        virtual
        override
        returns (uint256)
    {
        return (stableAmount * mintingFeePermil) / 1000;
    }

    function setMintingFeePermil(uint256 _feePermil) external onlyOwnerExec {
        mintingFeePermil = _feePermil;
    }
}
