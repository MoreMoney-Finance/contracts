// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Oracle.sol";
import "../../interfaces/IwsMAXI.sol";

contract WsMAXIOracle is Oracle {
    IwsMAXI public constant wsMAXI =
        IwsMAXI(0x2148D1B21Faa7eb251789a51B404fc063cA6AAd6);
    address public constant MAXI = 0x7C08413cbf02202a1c13643dB173f2694e0F73f0;

    uint256 public valueSmoothingPer10k = 1000;
    uint256 public lastValuePer1e18;
    uint256 public valuePer1e18;
    uint256 private lastUpdated;
    uint256 public updateWindow = 4 hours;

    constructor(address _roles) RoleAware(_roles) {}

    /// Convert inAmount to peg (view)
    function viewAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public view virtual override returns (uint256) {
        require(pegCurrency == MAXI, "Only map prices to MAXI");
        require(token == address(wsMAXI), "Only query for wsMAXI");
        return (inAmount * lastValuePer1e18) / 1e18;
    }

    /// Convert inAmount to peg (updating)
    function getAmountInPeg(
        address token,
        uint256 inAmount,
        address wrappedCurrency
    ) public virtual override returns (uint256) {
        uint256 value = viewAmountInPeg(token, inAmount, wrappedCurrency);

        if (block.timestamp - lastUpdated > updateWindow) {
            lastUpdated = block.timestamp;

            uint256 currentValPer1e18 = wsMAXI.wsMAXITosMAXI(1e18);
            lastValuePer1e18 = valuePer1e18;
            valuePer1e18 =
                (valueSmoothingPer10k *
                    valuePer1e18 +
                    (10_000 - valueSmoothingPer10k) *
                    currentValPer1e18) /
                10_000;
        }

        return value;
    }

    /// Set params
    function setOracleSpecificParams(address fromToken, address toToken)
        external
        onlyOwnerExec
    {
        bytes memory data = "";
        _setOracleParams(fromToken, toToken, data);
    }

    /// Set params
    function _setOracleParams(
        address fromToken,
        address toToken,
        bytes memory
    ) internal override {
        require(
            fromToken == address(wsMAXI) && toToken == MAXI,
            "Only map for MAXI"
        );
        uint256 currentValPer1e18 = wsMAXI.wsMAXITosMAXI(1e18);
        valuePer1e18 = currentValPer1e18;
        lastValuePer1e18 = currentValPer1e18;
        lastUpdated = block.timestamp;
    }

    /// Encode params for initialization
    function encodeAndCheckOracleParams(address fromToken, address toToken)
        external
        view
        returns (bool, bytes memory)
    {
        require(
            fromToken == address(wsMAXI) && toToken == MAXI,
            "Only map for MAXI"
        );
        bool matches = valuePer1e18 > 0;
        return (matches, "");
    }

    function setValueSmoothingPer10k(uint256 smoothingPer10k)
        external
        onlyOwnerExec
    {
        require(10_000 >= smoothingPer10k, "Needs to be less than 10k");
        valueSmoothingPer10k = smoothingPer10k;
        emit ParameterUpdated("value smoothing", smoothingPer10k);
    }

    function setUpdateWindow(uint256 window) external onlyOwnerExec {
        updateWindow = window;
    }
}
