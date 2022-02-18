// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../MintableToken.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AuxLPT is MintableToken {
    using SafeERC20 for IERC20;

    uint256 immutable public minterBurnerRole;
    constructor(
        uint256 _minterBurnerRole,
        string memory _name,
        string memory _symbol,
        address _roles
    ) MintableToken(_name, _symbol, type(uint256).max, _roles) {
        roleCache[msg.sender][_minterBurnerRole] = Roles(_roles).roles(
            msg.sender,
            _minterBurnerRole
        );
        minterBurnerRole = _minterBurnerRole;
    }

    function isAuthorizedMinterBurner(address caller)
        internal
        override
        returns (bool)
    {
        if (roleCache[caller][minterBurnerRole]) {
            return true;
        } else {
            updateRoleCache(minterBurnerRole, caller);
            return roleCache[caller][minterBurnerRole];
        }
    }

    function setApproval(address approvee, address token, uint256 amount) external {
        require(isAuthorizedMinterBurner(msg.sender) || owner() == msg.sender || executor() == msg.sender, "Caller not authorized to set approval");
        require(isAuthorizedMinterBurner(approvee), "Approvee is not an authorized minter / burner");
        IERC20(token).safeApprove(approvee, amount);
    }
}
