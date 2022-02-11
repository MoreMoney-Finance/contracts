// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Oracle.sol";
import "../../interfaces/IGlpManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract fsGLPOracle is Oracle {
    IGlpManager public glpManager = IGlpManager(0xe1ae4d4b06A5Fe1fc288f6B4CD72f9F8323B107F);
    address public constant fsGlp = 0x9e295B5B976a184B14aD8cd72413aD846C299660;
    IERC20 public glp = IERC20(0x01234181085565ed162a948b6a5e88758CD7c7b8);

    uint256 public valueSmoothingPer10k = 1000;
    uint256 public lastValuePer1e18;
    uint256 public valuePer1e18;
    uint256 private lastUpdated;
    uint256 public updateWindow = 20 minutes;

    constructor(address _roles) RoleAware(_roles) {}

    /// Convert inAmount to peg (view)
    function viewAmountInPeg(address token, uint256 inAmount, address) public view virtual override returns (uint256) {
        require(token == fsGlp || token == address(glp), "Only for fsGLP and GLP");
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

            uint256 currentValPer1e18 = glpManager.getAum(false) / IERC20(glp).totalSupply();
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
        address,
        bytes memory
    ) internal override {
                require(fromToken == fsGlp || fromToken == address(glp), "Only for fsGLP and GLP");

        uint256 currentValPer1e18 = glpManager.getAum(false) / IERC20(glp).totalSupply();
        valuePer1e18 = currentValPer1e18;
        lastValuePer1e18 = currentValPer1e18;
        lastUpdated = block.timestamp;
    }

    /// Encode params for initialization
    function encodeAndCheckOracleParams(address fromToken, address)
        external
        view
        returns (bool, bytes memory)
    {
        require(fromToken == fsGlp || fromToken == address(glp), "Only for fsGLP and GLP");
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