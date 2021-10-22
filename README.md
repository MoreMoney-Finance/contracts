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

# Disclaimer

This is alpha software, demonstrating functionality and proficiency, which has not yet been reviewed and tested rigorously.
