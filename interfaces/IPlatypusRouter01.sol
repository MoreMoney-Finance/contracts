// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IPlatypusRouter01 {
    function swapTokensForTokens(
        address[] calldata tokenPath,
        address[] calldata poolPath,
        uint256 fromAmount,
        uint256 minimumToAmount,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 haircut);
}
