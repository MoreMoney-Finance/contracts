// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../YieldConversionBidStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IMasterChef.sol";

contract MasterChefStrategy is YieldConversionBidStrategy {
    using SafeERC20 for IERC20;

    IMasterChef public immutable chef;
    mapping(address => uint256) public pids;

    constructor(
        bytes32 stratName,
        address _chef,
        address _rewardToken,
        address _roles
    )
        Strategy(stratName)
        YieldConversionBidStrategy(_rewardToken)
        TrancheIDAware(_roles)
    {
        chef = IMasterChef(_chef);
    }

    function collectCollateral(
        address source,
        address ammPair,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        IERC20(ammPair).safeTransferFrom(
            source,
            address(this),
            collateralAmount
        );
        IERC20(ammPair).approve(address(chef), collateralAmount);
        chef.deposit(pids[ammPair], collateralAmount);

        return collateralAmount;
    }

    function returnCollateral(
        address recipient,
        address ammPair,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        chef.withdraw(pids[ammPair], collateralAmount);
        IERC20(ammPair).safeTransfer(recipient, collateralAmount);

        return collateralAmount;
    }

    function _viewTargetCollateralAmount(uint256 collateralAmount, address)
        internal
        pure
        override
        returns (uint256)
    {
        return collateralAmount;
    }

    function _approveToken(address token, bytes calldata data)
        internal
        override
    {
        uint256 pid = abi.decode(data, (uint256));
        require(
            address(chef.poolInfo(pid).lpToken) == token,
            "Provided PID does not correspond to MasterChef"
        );
        pids[token] = pid;

        super._approveToken(token, data);
    }

    function checkApprovedAndEncode(address token, uint256 pid)
        public
        view
        returns (bool, bytes memory)
    {
        return (approvedToken(token), abi.encode(pid));
    }
}
