// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Oracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WrapperTokenOracle is Oracle {
    constructor(address _roles) RoleAware(_roles) {}

    uint256 public valueSmoothingPer10k = 5_000;
    uint256 updateWindow = 5 minutes;

    struct OracleState {
        uint256 lastValuePer1e18;
        uint256 valuePer1e18;
        uint256 lastUpdated;
        address wrappedToken;
    }

    mapping(address => OracleState) public oracleState;

    /// Convert inAmount to peg (view)
    function viewAmountInPeg(
        address token,
        uint256 inAmount,
        address wrappedCurrency
    ) public view virtual override returns (uint256) {
        OracleState storage state = oracleState[token];
        require(
            wrappedCurrency == state.wrappedToken,
            "Querying for wrong wrapped token"
        );
        return (inAmount * state.lastValuePer1e18) / 1e18;
    }

    /// Convert inAmount to peg (updating)
    function getAmountInPeg(
        address token,
        uint256 inAmount,
        address wrappedCurrency
    ) public virtual override returns (uint256) {
        uint256 value = viewAmountInPeg(token, inAmount, wrappedCurrency);
        OracleState storage state = oracleState[token];

        if (block.timestamp - state.lastUpdated > updateWindow) {
            state.lastUpdated = block.timestamp;

            uint256 totalSupply = IERC20(token).totalSupply();
            uint256 balance = IERC20(wrappedCurrency).balanceOf(token);

            uint256 currentValPer1e18 = (1e18 * balance) / totalSupply;
            state.lastValuePer1e18 = state.valuePer1e18;
            state.valuePer1e18 =
                (valueSmoothingPer10k *
                    state.valuePer1e18 +
                    (10_000 - valueSmoothingPer10k) *
                    currentValPer1e18) /
                10_000;
        }

        return value;
    }

    /// Set the wrapped currency
    function setOracleSpecificParams(address fromToken, address toToken)
        external
        onlyOwnerExec
    {
        _setOracleSpecificParams(fromToken, toToken);
    }

    /// Set the wrapped currency
    function _setOracleSpecificParams(address fromToken, address toToken)
        internal
    {
        OracleState storage state = oracleState[fromToken];
        require(
            state.wrappedToken == address(0) || state.wrappedToken == toToken,
            "Trying to overwrite existing wrapper"
        );
        state.wrappedToken = toToken;

        uint256 totalSupply = IERC20(fromToken).totalSupply();
        uint256 balance = IERC20(toToken).balanceOf(fromToken);

        state.valuePer1e18 = (1e18 * balance) / totalSupply;
        state.lastValuePer1e18 = (1e18 * balance) / totalSupply;
        state.lastUpdated = block.timestamp;
        emit SubjectUpdated("oracle specific params", fromToken);
    }

    /// Set value proxy
    function _setOracleParams(
        address fromToken,
        address toToken,
        bytes memory
    ) internal override {
        _setOracleSpecificParams(fromToken, toToken);
    }

    /// Encode params for initialization
    function encodeAndCheckOracleParams(address tokenFrom, address tokenTo)
        external
        view
        returns (bool, bytes memory)
    {
        bool matches = oracleState[tokenFrom].wrappedToken == tokenTo;
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
