# Introduction

Moremoney is a decentralized borrowing protocol that lets you take on Interest Free loans using both liquid and illiquid tokens as collateral, while still earning farm reward and/or interest on your collateral. Loans are issued out in the protocol's dollar pegged stablecoin.
Base tokens like USDT, ETH, AVAX as well as LPT and other form of ibTKNs are supported as collateral. 

# Simple steps
A simple overview on how things works 

1. User Deposits collateral and Borrows the protocol's stablecoin

2. Collateral is forwarded to partner protocols Example YY, Traderjoe or Pangolin to earn interest and/or farm reward 

3. Reward is compounded or used to pay back the loan


# Moremoney protocol core contracts

Stablecoin lending against yield-bearing collateral.

- `Stablecoin`: The mintable stablecoin
- `IsolatedLendingTranche` and `Tranche`: The user-facing contract ERC721 contract representing a tranche of tokens against which a user can borrow.
- `Strategy`: The abstract parent class of all the strategies in the `strategies` subfolder, to which the `Tranche` contracts forward their assets. There are auto-repaying strategies (`YieldConversionStrategy` and its descendants) and compounding strategies (e.g. `YieldYakStrategy`), as well as `SimpleHoldingStrategy` which does not generate yield.
- `oracles/*`: A selection of fine oracles. Liquidity pools are tracked jointly with general TWAP oracles. There are means to proxy from one ground-truth oracle to derived oracles (e.g. via TWAP).
- `Roles`: Contracts declare which roles they play and which other roles they depend on. `DependencyController` keeps track of all this and `Executor`/`controller-actions` are ways to effect changes to the roles system. The `roles` subfolder shoehorns the solidity type system into providing some typechecking support of role dependencies.


Every supported asset, has a yield generation strategy assigned to it that features

- `Compounding`: Yield earned by underlying collateral is compounded thereby increasing vault cRatio and borrowing power
-  `Autorepayment`: Yield earned by underlying collateral is converted to USDm and used to wipe out users debt position

-  Interestingly, both options reduce the likelihood of a vault falling below the liquidation threshold.


## Install

Install dependencies:
```(shell)
yarn install
```

Place a private key file in your home folder `~/.moremoney-secret`. If you want it to match up with your wallet like MetaMask, create the account in your wallet, copy the private key and paste it into the file.

## Disclaimer

This is alpha software, demonstrating functionality and proficiency, which has not yet been reviewed and tested rigorously.

## The lending process

## Strategies



## Oracles

The protocol provides a central point for governance to register oracles in `OracleRegistry`. Oracles generally provide a way to convert amounts in one token into another and are specifically used to convert amounts in a variety of accepted collateral tokens into amounts in our USD-pegged stablecoin (often represented by converting into USD or other USD-pegged tokens).

Oracle calls are offered as view functions or state-updating.

### Chainlink oracle

Chainlink provides a strong stable of USD price feeds on a variety of networks. The main issues to bear in mind are oracle freshness and correct decimal conversion. In order to guard against stale chainlink pricefeeds, our oracles also maintain a fallback TWAP oracle, using another reputable stablecoin as stand-in for USD price.

### TWAP oracle

UniswapV2-style AMM pairs maintain a time-weighted cumulative price, which our protocol relies on by choosing suitable AMM pairs. Important issues here are available liquidity, which is held in a dispersed way or locked up (to guard against price manipulations and sudden withdrawals), as well as overflows & properly scaled fixed point math, as the cumulative price numbers are returned as `2 ** 112` fixed point numbers. The oracle maintains ongoing state on the pair, which can be re-used for LPT oracles.

### Scaled oracle

The scaled oracle converts from one token to the other by multiplication by a constant factor. Useful for converting trusted pegged stables.

### Proxy oracle

The proxy oracle converts from token A to token B via token C, by looking up oracles between A and C, then B and C and chaining their token amount conversions.

### LPT oracle
