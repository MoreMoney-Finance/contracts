// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DependentContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract DependsOnProtocolToken is DependentContract {
    constructor() {
        _dependsOnCharacters.push(PROTOCOL_TOKEN);
    }

    function protocolToken() internal view returns (IERC20) {
        return IERC20(mainCharacterCache[PROTOCOL_TOKEN]);
    }
}
