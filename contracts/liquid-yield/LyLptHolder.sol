// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../roles/RoleAware.sol";
import "../roles/DependsOnLiquidYield.sol";
import "../../interfaces/IMasterChefJoeV3.sol";

/// Holds LPT in masterchef for yield (and forwards yield to redistributor)
contract LyLptHolder is RoleAware, DependsOnLiquidYield {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    IMasterChefJoeV3 public constant chef =
        IMasterChefJoeV3(0x188bED1968b795d5c9022F6a0bb5931Ac4c18F00);
    IERC20 public constant pair =
        IERC20(0x4b946c91C2B1a7d7C40FB3C130CdfBaf8389094d);
    uint256 constant pid = 51;

    EnumerableSet.AddressSet internal rewardTokens;
    EnumerableSet.AddressSet internal rewardRecipients;
    mapping(address => uint256) public rewardRecipientWeight;
    uint256 public rewardWeightTotal = 0;

    constructor(
        address[] memory _rewardTokens,
        address[] memory recipients,
        uint256[] memory weights,
        address _roles
    ) RoleAware(_roles) {
        _charactersPlayed.push(LIQUID_YIELD_HOLDER);

        for (uint256 i; recipients.length > i; i++) {
            rewardRecipients.add(recipients[i]);
            rewardRecipientWeight[recipients[i]] += weights[i];
            rewardWeightTotal += weights[i];
        }

        for (uint256 i; _rewardTokens.length > i; i++) {
            rewardTokens.add(_rewardTokens[i]);
        }
    }

    /// Deposit balance in LPT to masterchef
    function deposit() external {
        require(isLiquidYield(msg.sender), "Only for liquid yield role");
        chef.deposit(pid, pair.balanceOf((address(this))));
        forwardReward();
    }

    /// Withdraw LPT from masterchef
    function withdraw(uint256 amount, address recipient) external {
        require(isLiquidYield(msg.sender), "Only for liquid yield role");
        chef.withdraw(pid, amount);
        forwardReward();
        pair.safeTransfer(recipient, amount);
    }

    /// Harvest yield from masterchef
    function harvestPartially() external {
        chef.withdraw(pid, 0);
        forwardReward();
    }

    /// Forward rewards to all registered reward recipients
    function forwardReward() public {
        require(isLiquidYield(msg.sender), "Only for liquid yield role");

        for (uint256 i; rewardTokens.length() > i; i++) {
            IERC20 token = IERC20(rewardTokens.at(i));
            uint256 rewardTotal = token.balanceOf(address(this));
            for (uint256 j; rewardRecipients.length() > j; j++) {
                address recipient = rewardRecipients.at(j);
                token.safeTransfer(
                    recipient,
                    (rewardTotal * rewardRecipientWeight[recipient]) /
                        rewardWeightTotal
                );
            }
        }
    }

    /// Withdraw all LPT from masterchef and forward to recipient
    function withdrawAll(address recipient) external {
        require(isLiquidYield(msg.sender), "Only for liquid yield role");
        chef.withdraw(pid, viewStakedBalance());
        forwardReward();
        pair.safeTransfer(recipient, pair.balanceOf(address(this)));
    }

    /// View how much LPT is staked
    function viewStakedBalance() public view returns (uint256) {
        (uint256 balance, ) = chef.userInfo(pid, address(this));
        return balance;
    }

    /// View the list of reward tokens
    function viewRewardTokens() external view returns (address[] memory) {
        return rewardTokens.values();
    }

    /// View the list of reward recipients
    function viewRewardRecipients()
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        address[] memory recipients = new address[](rewardRecipients.length());
        uint256[] memory weights = new uint256[](rewardRecipients.length());

        for (uint256 i; rewardRecipients.length() > i; i++) {
            address recipient = rewardRecipients.at(i);
            recipients[i] = recipient;
            weights[i] = rewardRecipientWeight[recipient];
        }

        return (recipients, weights);
    }

    /// Set share of reward that recipient should receive
    function setRewardWeight(address recipient, uint256 w) external onlyOwnerExec {
        uint256 extantWeight = rewardRecipientWeight[recipient];
        rewardWeightTotal = rewardWeightTotal + w - extantWeight;
        rewardRecipientWeight[recipient] = w;
        if (w == 0) {
            rewardRecipients.remove(recipient);
        } else {
            rewardRecipients.add(recipient);
        }
    }

    /// Rescue stranded funds
    function rescueFunds(
        address token,
        address recipient,
        uint256 amount
    ) external onlyOwnerExec {
        IERC20(token).safeTransfer(recipient, amount);
    }

    /// register a reward token
    function addRewardToken(address token) external onlyOwnerExec {
        rewardTokens.add(token);
    }

    /// unregister a reward token
    function removeRewardtoken(address token) external onlyOwnerExec {
        rewardTokens.remove(token);
    }
}
