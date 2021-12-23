// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ProtocolToken is ERC20 {
    constructor(uint256 targetSupply)
        ERC20("MoreMoney", "MORE")
    {
        _mint(msg.sender, targetSupply);
    }
}
