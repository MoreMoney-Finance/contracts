// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./Oracle.sol";
import "./OracleAware.sol";
import "../roles/DependsOnStableCoin.sol";

/// Use chainlink to get dollar values for tokens
/// Fallback throws exception
contract ChainlinkNonStaleOracle is Oracle, OracleAware, DependsOnStableCoin {
    uint256 immutable pegDecimalFactor;
    uint256 immutable standinDecimalFactor;

    struct ChainlinkOracleParams {
        AggregatorV3Interface oracle;
        uint256 oracleDecimalFactor;
        uint256 tokenDecimalFactor;
    }

    mapping(address => ChainlinkOracleParams) public clOracleParams;
    uint256 public stalenessWindow = 2 hours;

    constructor(uint256 standinDecimals, address _roles) RoleAware(_roles) {
        pegDecimalFactor = 1e18;
        standinDecimalFactor = 1e18 / (10**standinDecimals);
    }

    /// Retrieve data from chainlink price feed
    function getChainlinkPrice(AggregatorV3Interface oracle)
        public
        view
        returns (uint256, uint256)
    {
        (, int256 tokenPrice, , uint256 tstamp, ) = oracle.latestRoundData();

        return (uint256(tokenPrice), tstamp);
    }

    /// When to declare chainlink stale
    function setStalenessWindow(uint256 staleness) external onlyOwnerExec {
        stalenessWindow = staleness;

        emit ParameterUpdated("staleness window", staleness);
    }

    /// View converted amount in peg currency
    function viewAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public view override returns (uint256) {
        require(
            pegCurrency == address(stableCoin()),
            "Chainlink just used for USD val"
        );
        ChainlinkOracleParams storage params = clOracleParams[token];

        (uint256 oraclePrice, uint256 tstamp) = getChainlinkPrice(
            params.oracle
        );
        require(
            (block.timestamp > tstamp + stalenessWindow) == false,
            "Price is stale"
        );
        return
            (pegDecimalFactor * inAmount * oraclePrice) /
            params.oracleDecimalFactor /
            params.tokenDecimalFactor;
    }

    /// Get converted amount in peg currency, updating fallback twap
    function getAmountInPeg(
        address token,
        uint256 inAmount,
        address pegCurrency
    ) public override returns (uint256) {
        require(
            pegCurrency == address(stableCoin()),
            "Chainlink just used for USD val"
        );

        ChainlinkOracleParams storage params = clOracleParams[token];
        (uint256 oraclePrice, uint256 tstamp) = getChainlinkPrice(
            params.oracle
        );

        bool stale = block.timestamp > tstamp + stalenessWindow;
        require(
            stale == false &&
                (block.timestamp - tstamp > stalenessWindow) == false,
            "Price is stale"
        );
        return
            (pegDecimalFactor * inAmount * oraclePrice) /
            params.oracleDecimalFactor /
            params.tokenDecimalFactor;
    }

    /// Set oracle specific parameters: pricefeed and decimals
    function setOracleSpecificParams(
        address token,
        address pegCurrency,
        address oracle,
        uint256 tokenDecimals
    ) external onlyOwnerExec {
        _setOracleSpecificParams(token, pegCurrency, oracle, tokenDecimals);
        emit SubjectUpdated("oracle specific params", token);
    }

    /// Internal, set oracle specific params
    function _setOracleSpecificParams(
        address token,
        address pegCurrency,
        address oracle,
        uint256 tokenDecimals
    ) internal {
        require(
            pegCurrency == address(stableCoin()),
            "Chainlink just used for USD val"
        );
        clOracleParams[token] = ChainlinkOracleParams({
            oracle: AggregatorV3Interface(oracle),
            oracleDecimalFactor: 10**AggregatorV3Interface(oracle).decimals(),
            tokenDecimalFactor: 10**tokenDecimals
        });
    }

    /// Set general oracle params
    function _setOracleParams(
        address token,
        address pegCurrency,
        bytes memory data
    ) internal override {
        (address oracle, uint256 tokenDecimals) = abi.decode(
            data,
            (address, uint256)
        );
        _setOracleSpecificParams(token, pegCurrency, oracle, tokenDecimals);
    }

    /// View encoded params for initialization
    function encodeAndCheckOracleParams(
        address token,
        address pegCurrency,
        address oracle,
        uint256 tokenDecimals
    ) external view returns (bool, bytes memory) {
        require(
            pegCurrency == address(stableCoin()),
            "Chainlink just used for USD val"
        );
        ChainlinkOracleParams storage clOracle = clOracleParams[token];
        bool matches = address(clOracle.oracle) == oracle &&
            clOracle.tokenDecimalFactor == 10**tokenDecimals;
        return (matches, abi.encode(oracle, tokenDecimals));
    }
}
