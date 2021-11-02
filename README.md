# Moremoney protocol core contracts

All the basic stablecoin lending infrastructure.

Currently has basic liquidation and yield farming / loan repayment infrastructure.

- `Stablecoin`: The mintable stablecoin
- `IsolatedLendingTranche` and `Tranche`: The user-facing contract ERC721 contract representing a tranche of tokens against which a user can borrow.
- `Strategy`: The abstract parent class of all the strategies in the `strategies` subfolder, to which the `Tranche` contracts forward their assets
- `oracles/*`: A selection of fine oracles
- `Roles`, `DependencyController` and `Executor`: underlying roles system managing service discovery and means for effecting changes using `controller-actions` -- the `roles` subfolder shoehorns the solidity type system into providing some typechecking support of dependencies


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
