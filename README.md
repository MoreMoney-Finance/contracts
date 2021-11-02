# Moremoney protocol core contracts

All the basic stablecoin lending infrastructure.

Currently has basic liquidation and yield farming / loan repayment infrastructure.

- `Stablecoin`: the mintable stablecoin
- `MintFromCollateral`: lending base class
- `MintFromLiqToken`: LPT lending
- `MintFromMasterChefLiqToken`: Master chef yield strategy
- `Roles`: underlying roles system


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
