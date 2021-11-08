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
