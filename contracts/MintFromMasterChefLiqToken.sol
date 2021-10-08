// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./MintFromLiqToken.sol";
import "./MintFromStrategy.sol";
import "../interfaces/IMasterChef.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// Use staking on Masterchef as yield strategy
contract MintFromMasterChefLiqToken is MintFromStrategy {
    using SafeERC20 for IERC20;

    IMasterChef public immutable chef;
    uint256 public immutable pid;

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
        MintFromStrategy(
            _ammPair,
            _oracleForToken0,
            _oracleForToken1,
            _reservePermil,
            _rewardToken,
            _conversionBidWindow,
            _roles
        )
    {
        chef = IMasterChef(_chef);
        pid = _pid;
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

}
