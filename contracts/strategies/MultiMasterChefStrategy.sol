// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./MultiYieldConversionStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IMasterChefJoeV3.sol";

/// Self-repaying strategy using MasterChef rewards
contract MultiMasterChefStrategy is MultiYieldConversionStrategy {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    IMasterChefJoeV3 public immutable chef;
    mapping(address => uint256) internal pids;

    address public mainRewardToken;

    constructor(
        bytes32 stratName,
        address _chef,
        address _rewardToken,
        address _wrappedNative,
        address _roles
    )
        Strategy(stratName)
        TrancheIDAware(_roles)
        MultiYieldConversionStrategy(_wrappedNative)
    {
        chef = IMasterChefJoeV3(_chef);
        mainRewardToken = _rewardToken;
    }

    /// We encode PIDs in such a way so that an unset PID throws an eror
    function viewPid(address token) public view returns (uint256) {
        return pids[token] - 1;
    }

    /// send tokens to masterchef
    function collectCollateral(
        address source,
        address ammPair,
        uint256 collateralAmount
    ) internal override {
        IERC20(ammPair).safeTransferFrom(
            source,
            address(this),
            collateralAmount
        );
        IERC20(ammPair).safeIncreaseAllowance(address(chef), collateralAmount);
        chef.deposit(viewPid(ammPair), collateralAmount);
        tallyReward(ammPair);
    }

    /// withdraw back to user
    function returnCollateral(
        address recipient,
        address ammPair,
        uint256 collateralAmount
    ) internal override returns (uint256) {
        require(recipient != address(0), "Don't send to zero address");

        uint256 balanceBefore = IERC20(ammPair).balanceOf(address(this));
        chef.withdraw(viewPid(ammPair), collateralAmount);
        uint256 balanceDelta = IERC20(ammPair).balanceOf(address(this)) -
            balanceBefore;
        tallyReward(ammPair);
        IERC20(ammPair).safeTransfer(recipient, balanceDelta);

        return balanceDelta;
    }

    /// Internal, initialize a token
    function _approveToken(address token, bytes calldata data)
        internal
        override
    {
        (uint256 pid, address[] memory _rewardTokens) = abi.decode(
            data,
            (uint256, address[])
        );
        require(
            address(chef.poolInfo(pid).lpToken) == token,
            "Provided PID does not correspond to MasterChef"
        );
        pids[token] = pid + 1;

        EnumerableSet.AddressSet storage ourRewardTokens = rewardTokens[token];
        for (uint256 i; _rewardTokens.length > i; i++) {
            ourRewardTokens.add(_rewardTokens[i]);
        }
        ourRewardTokens.add(mainRewardToken);

        super._approveToken(token, data);
    }

    /// Initialization, encoding args
    function checkApprovedAndEncode(
        address token,
        uint256 pid,
        address[] calldata _rewardTokens
    ) public view returns (bool, bytes memory) {
        bool allIncluded = true;
        EnumerableSet.AddressSet storage ourRewardTokens = rewardTokens[token];
        for (uint256 i; _rewardTokens.length > i; i++) {
            allIncluded =
                allIncluded &&
                ourRewardTokens.contains(_rewardTokens[i]);
        }
        return (
            approvedToken(token) && pids[token] == pid + 1 && allIncluded,
            abi.encode(pid, _rewardTokens)
        );
    }

    /// Harvest from Masterchef
    function harvestPartially(address token) external override nonReentrant {
        uint256 pid = viewPid(token);
        chef.withdraw(pid, 0);
        tallyReward(token);
    }

    /// View pending reward
    function viewSourceHarvestable(address token)
        public
        view
        override
        returns (uint256)
    {
        uint256 pid = viewPid(token);
        return
            _viewValue(
                mainRewardToken,
                chef.pendingTokens(pid, address(this)),
                yieldCurrency()
            );
    }

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
        uint256 points = chef.poolInfo(pids[token]).allocPoint;
        return
            10_000 +
            ((10_000 - feePer10k) * (365 days) * perSecValue * points) /
            chef.totalAllocPoint() /
            stakedValue;
    }

    // View the underlying yield strategy (if any)
    function viewUnderlyingStrategy(address)
        public
        view
        virtual
        override
        returns (address)
    {
        return address(chef);
    }
}
