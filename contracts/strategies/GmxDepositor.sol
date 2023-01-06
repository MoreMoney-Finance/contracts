// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IGmxDepositor.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GmxDepositor is IGmxDepositor, Ownable {
    address public proxy;

    modifier onlyGmxProxy() {
        require(msg.sender == proxy, "GmxDepositor::onlyGmxProxy");
        _;
    }

    function setGmxProxy(address _proxy) external override onlyOwner {
        proxy = _proxy;
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external override onlyGmxProxy returns (bool, bytes memory) {
        (bool success, bytes memory result) = target.call{value: value}(data);

        return (success, result);
    }
}
