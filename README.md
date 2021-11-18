# Moremoney protocol core contracts

Moremoney is a decentralized borrowing protocol that lets you take on Interest Free loans using both liquid and illiquid tokens as collateral, while still earning farm reward and/or interest on your collateral. Loans are issued out in the protocol's dollar pegged stablecoin.
Base tokens like USDT, ETH, AVAX as well as LPT and other form of ibTKNs are supported as collateral. 

# Install

Install dependencies:
```(shell)
yarn install
```

Place a private key file in your home folder `~/.moremoney-secret`. If you want it to match up with your wallet like MetaMask, create the account in your wallet, copy the private key and paste it into the file.

# Disclaimer

This is alpha software, demonstrating functionality and proficiency, which has not yet been reviewed and tested rigorously.

# Documentation

## The lending process

### A simple overview on how things work:

1. User Deposits collateral and Borrows the protocol's stablecoin
2. Collateral is forwarded to partner protocols. (E.g. YieldYak, TraderJoe or Pangolin) to earn interest and/or farm reward 
3. Reward is compounded or used to pay back the loan

Every supported asset has a yield generation strategy assigned to it that features:

- `Compounding`: Yield earned by underlying collateral is compounded thereby increasing vault cRatio and borrowing power
-  `Autorepayment`: Yield earned by underlying collateral is converted to USDm and used to wipe out users debt position

Both options reduce the likelihood of a vault falling below the liquidation threshold.

## Contracts overview

- `Stablecoin`: The mintable stablecoin
- `IsolatedLendingTranche` and `Tranche`: The user-facing contract ERC721 contract representing a tranche of tokens against which a user can borrow.
- `Strategy`: The abstract parent class of all the strategies in the `strategies` subfolder, to which the `Tranche` contracts forward their assets. There are auto-repaying strategies (`YieldConversionStrategy` and its descendants) and compounding strategies (e.g. `YieldYakStrategy`), as well as `SimpleHoldingStrategy` which does not generate yield.
- `oracles/*`: A selection of fine oracles. Liquidity pools are tracked jointly with general TWAP oracles. There are means to proxy from one ground-truth oracle to derived oracles (e.g. via TWAP).
- `Roles`: Contracts declare which roles they play and which other roles they depend on. `DependencyController` keeps track of all this and `Executor`/`controller-actions` are ways to effect changes to the roles system. The `roles` subfolder shoehorns the solidity type system into providing some typechecking support of role dependencies.


## Roles

In order to reduce the attack surface, ownership and control of parameters and other roles is concentrated and managed in one contract: `Roles.sol` (with significant assistance by `DependencyController.sol`). `Roles.sol` is kept very simple on purpose and has been previously used successfully as basis for the Marginswap protocol. The `currentExecutor` variable in `DependencyController` is set and unset only once in the code base.

Ownership will be held in a multi-signature wallet for a brief beta period, during which limiting parameters will be strict and risks are discouraged, while the functional viability of the system is tested, with the ability to quickly react. After this the community will add a timelock and transfer ownership to Compound-style governance.

Contracts within the deployed system are intrinsically immutable and loosely coupled, i.e. individual parts of the system may be replaced and new contracts with similar roles/powers as existing contracts can be added. This is useful for centrally and consistently managing minting/burning privileges, responding to changing liquidation and harvesting needs etc. In order to keep gas costs manageable, roles assignments are cached locally per contract (cf. `DependentContract.sol` and `RoleAware.sol`) and updated by `DependencyController.sol` , since contracts can broadcast their dependence on being notified of role updates for any specific role. Thereby finding a balance between a system responsive to changing needs and contract immutability.

'Roles' fall into two categories:
- Main characters: One unique contract performing a unique role within the entire system. (E.g. strategy registry or the stablecoin) Used for service discovery.
- Roles: Multiple contracts can be marked as holding a role. Used for access control checking (E.g. minter / burner, fund transferer on behalf of users)

## Strategies

Tranche contracts (of which `IsolatedLending` is the only deployed instance) forward collateral assets to other contracts, strategies, which in turn have the logic for tracking and interacting with other yield-bearing systems.

### Auto-repaying strategies: `YieldConversionStrategy`

Stages of auto-repayment:
- Reward tokens for a specific asset have been transfered to the strategy, either because the user triggered a deposit or withdraw, or because they called `harvestPartially` to induce the yield generating contract to distribute reward.
- `tallyReward(address token)` assigns that excess reward balance to an underlying asset within the contract's internal accounting.
- `convertReward2Stable` can be called by anyone in order to convert accumulated reward tokens into our stablecoin, at their current USD price.
- `tallyHarvestBalance(address token)` finally makes this harvested stable accrue to accounts as loan repayment

The `AMMYieldConverter` contract offers a way to do this entire process in one transaction, including unwinding reward tokens on AMMs.

#### MasterChef auto-repaying

- `MasterChef`-style contracts often transfer reward upon every interaction, so `tallyReward` is called at each withdraw and deposit.

#### Synthetix-style staking rewards auto-repaying

### YieldYak auto-compounding

## Liquidation

## Self-repayment

## Compounding fees

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

UniswapV2-style AMM pairs mint LP tokens which our protocol accepts as collateral. Oracles for this asset class have widely been implemented [according to the "fair LPT oracle" method](https://blog.alphafinance.io/fair-lp-token-pricing/), which does leave room for some potential vulnerabilities.

According to the amount of `burn` function in `UniswapV2Pair`, one unit of LPT `liquidity` corresponds to a proportional share of both underlying asset reserves:

```solidity
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
```

The algorithm proposed by Alpha Homora goes as follows:
![image](https://user-images.githubusercontent.com/603348/141697293-d134daeb-3a25-4ae0-aee9-b0c1bc3f63e4.png)

This oracle can potentially make a lending protocol vulnerable:
- An attacker might manipulate the reserves by dumping in more balance and triggering an update inflating `k = r0 * r1`, while leaving the `totalSupply` the same.
- If an attacker were able to a acquire a (potentially leveraged) position with gains from the price manipulation in excess of the cost of manipulating the price, they could extract value from the protocol.

Acquiring such an extreme position in a stablecoin lending protocol against an ostensibly illiquid asset may not be as readily possible as in a p2p lending system, nevertheless caution is indicated.

The measures we take to combat attacks are as follows:
- We do not use the current values for `k` and `totalSupply` within a block in which they are updated and we space updates by a reasonable interval, such as 5 minutes.
- Deposits are capped to a fraction of the total supply (again not the current-block value)
- In some instances we can smooth updates to these core parameters and / or only let updates be performed by whitelisted addresses (to be implemented as necessary)
- We add an additional time-weighted component to our price calculations (see below)

These measures also apply to other synthetic assets where prices or conversion factors are subject to within-block changes.

In order to better re-use our existing oracle infrastructure, we adapt the LPT oracle formula in the following way:
- Instead of computing the oracle price solely on the basis of the most recent `k` value, we impute reserves based on `k` in conjunction with the cumulative price (see `contracts/oracles/TwapOracle.sol`, function `price0FP2Reserves` for the conversion formula derivation).
- We then compute the price for total supply and `k` of last update, in a straightforward way based on the sum of USD values of both reserves.

