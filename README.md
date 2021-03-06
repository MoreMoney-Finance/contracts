# Moremoney protocol core contracts

Moremoney is a decentralized borrowing protocol that lets you take on Interest Free loans using both liquid and illiquid tokens as collateral, while still earning farm reward and/or interest on your collateral. Loans are issued out in the protocol's dollar pegged stablecoin.
Base tokens like USDT, ETH, AVAX as well as LPT and other form of ibTKNs are supported as collateral. 

# Install

Install dependencies:
```(shell)
yarn install
```

Place a private key file in your home folder `~/.moremoney-secret`. If you want it to match up with your wallet like MetaMask, create the account in your wallet, copy the private key and paste it into the file.

## Getting deploy ready

- Get a snowtrace / etherscan API key and put it in `.etherscan-keys.json` (in project root folder), formatted like this `{ "avalanche": "YOURSECRETKEYGOESHERE" }`
- copy a current addresses.json file into `build/addresses.json`
- Run `yarn deploy avalanche` (In order to replace an already deployed contract add it like this `yarn deploy avalanche FooContract`
- The deploy script will export a new `addresses.json` to the frontend repo in the same parent folder

# Usage

If you want a completely fresh deploy, without relying on the forked existing protocol, run:
```(shell)
yarn dev
```

To run a local fork of the protocol, as deployed on avalanche, run:

```(shell)
yarn start
```

To deploy any new contracts to that fork as well as additional tokens and strategy activations, run the following in a separate shell session:

```(shell)
yarn local-deploy
```

If you want to deploy any changes you made to existing contracts, you have to name those contracts, like so:

```(shell)
yarn local-deploy DirectFlashLiquidation WrapNativeIsolatedLending
```

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

- `Stablecoin`: The mintable stablecoin (also provides ERC3156 flash loans)
- `IsolatedLendingTranche` and `Tranche`: The user-facing contract ERC721 contract representing a tranche of tokens against which a user can borrow.
- `Strategy`: The abstract parent class of all the strategies in the `strategies` subfolder, to which the `Tranche` contracts forward their assets. There are auto-repaying strategies (`YieldConversionStrategy` and its descendants) and compounding strategies (e.g. `YieldYakStrategy`), as well as `SimpleHoldingStrategy` which does not generate yield.
- `oracles/*`: A selection of fine oracles. Liquidity pools are tracked jointly with general TWAP oracles. There are means to proxy from one ground-truth oracle to derived oracles (e.g. via TWAP).
- `Roles`: Contracts declare which roles they play and which other roles they depend on. `DependencyController` keeps track of all this and `Executor`/`controller-actions` are ways to effect changes to the roles system. The `roles` subfolder shoehorns the solidity type system into providing some typechecking support of role dependencies.
- `Vault`: Currently not deployed, part of future protocol plans for cross-asset lending

Note: Since these contracts are not targeted at ETH mainnet at this time, less heed was given to gas optimization.

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

#### Attributing yield to accounts

- Every time yield gets converted from reward token to our stable, and the harvest balance is tallied, we create a yield checkpoint, reflecting how much yield has accrued up to that point.
- A configurable percentage of yield gets diverted to protocol funds upon conversion.
- Accounts keep track of a yield checkpoint index, indicating when in this list of checkpoints they started earning.
- The time period between checkpoints is a yield phase.
- Newly created accounts start accruing in the next phase after the next checkpoint is created.
- Exiting accounts are removed from the current yield phase collateral total.
- Total proceeds from a yield phase are divided by the collateral total for the current phase and stored in the checkpoint.
- Yield for an individual user is `collateral * (cumulativeYieldAtCurrentCheckpt - cumulativeYieldAtInitialCheckpt)` (cf. `Strategy._viewYield(account, tokenMeta, currency)` for the formula in action).

#### MasterChef auto-repaying

- `MasterChef`-style contracts often transfer reward upon every interaction, so `tallyReward` is called at each withdraw and deposit.
- The contract houses a variety of assets lodged in one `MasterChef` contract under one roof, checking the `pid` for each token upon token initialization.

#### Synthetix-style staking rewards auto-repaying

- Maintains a mapping from staking token to staking contract, checking integrity of mapping at initializtion.
- Reward contracts offer a direct way to harvest reward.

### YieldYak auto-compounding

- We use YieldYak for auto-compounding yield
- Deposited shares are stored along with deposited collateral amount
- At account update time, we calculate a new collateral amount taking the amount corresponding to deposited shares and subtracting a fee percentage from the delta compared to the deposited amount(cf `YieldYakStrategy._applyCompounding`)
- Thereby fees on yield are assessed by discounting the compounding

#### A note on price / valuation manipulations:
An attacker can potentially manipulate the *deposit tokens per share* ratio in the YieldYak strategy, within one transaction, by donating tokens to it. If that attacker were able to gain more from our protocol than it costs effect this manipulation, they would have a valid attack vector. We take the following measures:
- Deposit limits are set per-strategy, per-asset.
- The value adjustment by share price is local to the YieldYak strategy and does not infect price oracles in the rest of our protocol.
- Users cannot take a leveraged collateral position in this strategy while the yield generating strategy is sound (and tokens cannot be drained from it) and the strategy guarded against reentrancy a.
- If the yield generating YieldYak strategy were compromised, prudent deposit limits can guard against runaway position-building.
- Absent extreme upstream vulnerabilities, any action to donate funds to a compounding strategy simply results in additional yield to be distributed.

### Deprecating a strategy or asset

The strategies system offers a gradiated range of responses to strategy or token failure and/or deprecation.

- To deprecate a specific token in a specific strategy while leaving existing accounts intact: `setDepositLimit` to zero
- To deprecate an entire strategy: Repeat `setDepositLimit` for all the tokens in that strategy 
- To deactivate and replace a strategy immediately: execute `migrateAllTo(address destination)` on the strategy and all tranches for all assets managed by the strategy will see their assets withdrawn and housed temporarily until users interact with them again.
- To rescue stranded funds: `rescueCollateral`, `rescueStrandedTokens` and `rescueNative`.

### Strategy migration

With one call to `migrateStrategy` users can send their own assets in their tranche to a different yield-bearing strategy which supports that asset.

## Liquidation

Liquidation occurs in `IsolatedLendingLiquidation.sol`.

- Would-be liquidators bid a rebalancing amount in stablecoin with which to repay some debt of the liquidatable tranche.
- Liquidators can request a collateral amount by which they may be compensated, the value of which may not exceed their liquidation bid, plus a per-asset liquidation fee.
- After depositing the rebalancing amount of stablecoin and withdrawing the requested collateral to the liquidator, the tranche must be above the minimum collateralization threshold.
- The protocol additionally asseses a fee, as a portion of the requested collateral value, which can be set per-asset.

*NOTE:* In case a tranche goes underwater we reserve liquidation for governance and whitelisted addresses, in order to guard against oracle vulnerabilities.

We will also provide unprivileged convenience contracts to organize complete unwinding of positions using AMMs and stablecoin flash loans.

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

