// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./MiniChefStrategy.sol";

/// Use MiniChef pangolin
contract PangolinMiniChefStrategy is MiniChefStrategy {
    constructor(address _roles)
        MiniChefStrategy(
            "Pangolin self-repaying",
            0x1f806f7C8dED893fd3caE279191ad7Aa3798E928,
            0x60781C2586D68229fde47564546784ab3fACA982,
            _roles
        )
    {}
}
