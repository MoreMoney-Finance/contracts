// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract ProtocolToken is ERC20Permit {
    constructor(uint256 targetSupply)
        ERC20("MoreMoney", "MORE")
        ERC20Permit("MoreMoney")
    {
        _mint(msg.sender, targetSupply);
    }
}
