// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./VestingWrapper.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";


contract VestingMoreToken is VestingWrapper {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal protocolOwned;
    uint256 public protOwnedDecayPer10k = 100_000;

    constructor(address vestingToken)
        VestingWrapper("MORE That Vests", "MTV", vestingToken)
    {}

    function mintProtocolOwned(address holder, uint256 amount)
        external
        onlyOwner
    {
        protocolOwned.add(holder);
        _mint(holder, amount);
    }

    function removeProtocolOwned(address holder) external onlyOwner {
        protocolOwned.remove(holder);
    }

    function setProtOwnedDecay(uint256 speedupPer10k) external onlyOwner {
        protOwnedDecayPer10k = speedupPer10k;
    }

    function protocolBurn(address holder) public {
        require(protocolOwned.contains(holder), "Not a protocol owned account");

        uint256 vestedAmount = vestedByAccount(holder);
        uint256 burnAmount = min(
            balanceOf(holder),
            (protOwnedDecayPer10k * vesting2wrapper(vestedAmount)) / 10_000
        );

        _burn(holder, burnAmount);
    }

    function protocolBurnSync(address holder) public {
        protocolBurn(holder);
        IUniswapV2Pair(holder).sync();
    }
}
