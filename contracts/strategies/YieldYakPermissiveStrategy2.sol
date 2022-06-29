// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./YieldYakStrategy2.sol";

contract YieldYakPermissiveStrategy2 is YieldYakStrategy2 {
    using SafeERC20 for IERC20;

    constructor(address _roles) YieldYakStrategy2(_roles) {}

    /// Internal, initialize a token
    function _approveToken(address token, bytes calldata data)
        internal
        override
    {
        changeUnderlyingStrat(token, abi.decode(data, (address)));
        Strategy2._approveToken(token, data);
    }
}