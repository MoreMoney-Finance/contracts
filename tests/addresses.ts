export const addresses: Record<
  string,
  DeploymentAddresses
> = require('../build/addresses.json');

export type DeploymentAddresses = {
  Fund: string;
  Roles: string;
  IsolatedLendingLiquidation: string;
  DependencyController: string;
  OracleRegistry: string;
  Stablecoin: string;
  StrategyRegistry: string;
  TrancheIDService: string;
  TraderJoeMasterChefStrategy: string;
  TraderJoeMasterChef2Strategy: string;
  YieldYakAVAXStrategy: string;
  SimpleHoldingStrategy: string;
  YieldYakStrategy: string;
  PangolinMiniChefStrategy: string;
  AMMYieldConverter: string;
  WrapNativeIsolatedLending: string;
  CurvePoolRewards: string;
  DirectFlashLiquidation: string;
  LPTFlashLiquidation: string;

  MoreToken: string;
  xMore: string;

  StableLendingLiquidation: string;
  DirectFlashStableLiquidation: string;
  LPTFlashStableLiquidation: string;
  wsMAXIStableLiquidation: string;
  xJoeStableLiquidation: string;
  WrapNativeStableLending: string;
  sJoeStrategy: string;

  VestingLaunchReward: string;

  CurvePool: string;
  CurvePoolSL: string;
  CurvePoolSL2: string;
  StrategyViewer: string;

  LiquidYieldStrategy: string;
  MultiTraderJoeMasterChef3Strategy: string;
  InterestRateController: string;
  VeMoreToken: string;
  VeMoreStaking: string;
  iMoney: string;
  StableLending2: string;
  YieldYakAVAXStrategy2: string;
  YieldYakStrategy2: string;
  WrapNativeStableLending2: string;
  StableLending2Liquidation: string;
  StableLending2InterestForwarder: string;
};

export function useAddresses() {
  const chainId = 31337;

  // TODO make the default avalanche once it's supported by useDApp
  const chainIdStr = chainId ? chainId.toString() : '43114';
  return addresses[chainIdStr];
}
