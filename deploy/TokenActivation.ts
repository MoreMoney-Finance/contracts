// iterate over, group them up
// test their parameters all over the place?
// perhaps another central registry? -- to make idempotency easier

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { BigNumber } from '@ethersproject/bignumber';
import { parseEther, parseUnits } from '@ethersproject/units';
import IUniswapV2Factory from '@uniswap/v2-core/build/IUniswapV2Factory.json';
import IMasterChef from '../build/artifacts/interfaces/IMasterChef.sol/IMasterChef.json';
import pngrewards from '../data/pngrewards.json';
import path from 'path';
import * as fs from 'fs';

const baseCurrency = {
  kovan: 'WETH',
  mainnet: 'WETH',
  avalanche: 'WAVAX',
  hardhat: 'WAVAX',
  matic: 'WETH',
  bsc: 'WBNB'
};

export const tokensPerNetwork: Record<string, Record<string, string>> = {
  hardhat: {
    WAVAX: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
    WETHe: '0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB',
    PNG: '0x60781C2586D68229fde47564546784ab3fACA982',
    USDTe: '0xc7198437980c041c805A1EDcbA50c1Ce5db95118',
    // YAK: '0x59414b3089ce2AF0010e7523Dea7E2b35d776ec7',
    // QI: '0x8729438EB15e2C8B576fCc6AeCdA6A148776C0F5',
    // XAVA: '0xd1c3f94DE7e5B45fa4eDBBA472491a9f4B166FC4',
    JOE: '0x6e84a6216ea6dacc71ee8e6b0a5b7322eebc0fdd',
    USDCe: '0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664'
    // DAIe: '0xd586e7f844cea2f87f50152665bcbc2c279d8d70',
    // WBTCe: '0x50b7545627a5162f82a992c33b87adc75187b218'
  },
  avalanche: {
    WAVAX: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
    WETHe: '0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB',
    PNG: '0x60781C2586D68229fde47564546784ab3fACA982',
    USDTe: '0xc7198437980c041c805A1EDcbA50c1Ce5db95118',
    // YAK: '0x59414b3089ce2AF0010e7523Dea7E2b35d776ec7',
    // QI: '0x8729438EB15e2C8B576fCc6AeCdA6A148776C0F5',
    // XAVA: '0xd1c3f94DE7e5B45fa4eDBBA472491a9f4B166FC4',
    JOE: '0x6e84a6216ea6dacc71ee8e6b0a5b7322eebc0fdd',
    USDCe: '0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664'
    // DAIe: '0xd586e7f844cea2f87f50152665bcbc2c279d8d70',
    // WBTCe: '0x50b7545627a5162f82a992c33b87adc75187b218'
  }
};

export type OracleConfig = (
  primary: boolean,
  tokenAddress: string,
  record: TokenInitRecord,
  allTokens: Record<string, string>,
  hre: HardhatRuntimeEnvironment
) => Promise<[string, any[]]>;

export type TokenInitRecord = {
  decimals?: number;
  oracle: OracleConfig;
  debtCeiling: number;
  mintingFeePercent?: number;
  borrowablePercent?: number;
  additionalOracles?: [string, OracleConfig][];
  liquidationRewardPercent?: number;
};

function ChainlinkConfig(oracle: string): OracleConfig {
  return async (_primary, tokenAddress, record, _allTokens, hre) => [
    'ChainlinkOracle',
    [tokenAddress, (await hre.deployments.get('Stablecoin')).address, oracle, record.decimals ?? 18]
  ];
}

async function getPair(hre: HardhatRuntimeEnvironment, factoryContract: string, tokenA: string, tokenB: string) {
  const [token0, token1] = tokenA.toLowerCase() < tokenB.toLowerCase() ? [tokenA, tokenB] : [tokenB, tokenA];
  return (await hre.ethers.getContractAt(IUniswapV2Factory.abi, factoryContract)).getPair(token0, token1);
}

function TwapConfig(factoryContract: string, pegCurrency?: string): OracleConfig {
  return async (_primary, tokenAddress, _record, allTokens, hre) => {
    const peg = pegCurrency ? allTokens[pegCurrency] : (await hre.deployments.get('Stablecoin')).address;
    return ['TwapOracle', [tokenAddress, peg, await getPair(hre, factoryContract, tokenAddress, peg), true]];
  };
}

function TraderTwapConfig(pegCurrency?: string): OracleConfig {
  return TwapConfig('0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10', pegCurrency);
}

function PngTwapConfig(pegCurrency?: string): OracleConfig {
  return TwapConfig('0xefa94DE7a4656D787667C749f7E1223D71E9FD88', pegCurrency);
}

function EquivalentConfig(scale?: number, pegCurrency?: string): OracleConfig {
  return async (primary, tokenAddress, record, allTokens, hre) => [
    'EquivalentScaledOracle',
    [
      tokenAddress,
      pegCurrency ? allTokens[pegCurrency] : (await hre.deployments.get('Stablecoin')).address,
      parseUnits((scale ?? '1').toString(), record.decimals ?? 18),
      parseEther('1')
    ]
  ];
}

function ProxyConfig(proxyName: string, pegCurrency?: string): OracleConfig {
  return async (primary, tokenAddress, record, allTokens, hre) => {
    const peg = pegCurrency ? allTokens[pegCurrency] : (await hre.deployments.get('Stablecoin')).address;
    return ['ProxyOracle', [tokenAddress, peg, allTokens[proxyName]]];
  };
}

export const tokenInitRecords: Record<string, TokenInitRecord> = {
  WAVAX: {
    oracle: ChainlinkConfig('0x0a77230d17318075983913bc2145db16c7366156'),
    debtCeiling: 1000,
    additionalOracles: [['WAVAX', TraderTwapConfig('USDCe')]],
    borrowablePercent: 80,
    liquidationRewardPercent: 8
  },
  WETHe: {
    oracle: ChainlinkConfig('0x976b3d034e162d8bd72d6b9c989d545b839003b0'),
    debtCeiling: 100,
    additionalOracles: [['WETHe', TraderTwapConfig('USDCe')]],
    borrowablePercent: 80,
    liquidationRewardPercent: 8
  },
  USDCe: {
    oracle: EquivalentConfig(),
    debtCeiling: 1000,
    decimals: 6,
    borrowablePercent: 95,
    liquidationRewardPercent: 4
  },
  USDTe: {
    oracle: EquivalentConfig(),
    debtCeiling: 1000,
    decimals: 6,
    borrowablePercent: 95,
    liquidationRewardPercent: 4
  },
  JOE: {
    oracle: ProxyConfig('USDCe'),
    debtCeiling: 1000,
    additionalOracles: [['JOE', TraderTwapConfig('USDCe')]],
    borrowablePercent: 70,
    liquidationRewardPercent: 8
  },
  PNG: {
    oracle: ProxyConfig('WAVAX'),
    debtCeiling: 1000,
    additionalOracles: [['PNG', PngTwapConfig('WAVAX')]],
    borrowablePercent: 70,
    liquidationRewardPercent: 8
  }
};

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const lptTokenAddresses = await augmentInitRecordsWithLPT(hre);
  const { getNamedAccounts, deployments, getChainId, getUnnamedAccounts, network, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const targetTokens: string[] = [];
  const debtCeilings: BigNumber[] = [];
  const feesPer10k: BigNumber[] = [];
  const liquidationRewardsPer10k: BigNumber[] = [];

  const IL = await ethers.getContractAt('IsolatedLending', (await deployments.get('IsolatedLending')).address);

  const dC = await ethers.getContractAt(
    'DependencyController',
    (
      await deployments.get('DependencyController')
    ).address
  );

  const tokensInQuestion = Array.from(Object.entries(tokensPerNetwork[network.name])).concat(lptTokenAddresses);

  // first go over all the oracles
  const allOracleActivations = await collectAllOracleCalls(hre, tokensInQuestion);

  for (const [oracleAddress, oArgs] of Object.entries(allOracleActivations)) {
    const OracleActivation = await deploy('OracleActivation', {
      from: deployer,
      args: [
        oracleAddress,
        oArgs.tokens,
        oArgs.pegCurrencies,
        oArgs.borrowables,
        oArgs.primaries,
        oArgs.data,
        roles.address
      ],
      log: true
    });

    const tx = await dC.executeAsOwner(OracleActivation.address);
    console.log(`Executing oracle activation for ${oracleAddress}: ${tx.hash}`);
    await tx.wait();
  }

  for (const [tokenName, tokenAddress] of tokensInQuestion) {
    const initRecord = tokenInitRecords[tokenName];
    const debtCeiling = parseEther(initRecord.debtCeiling.toString());
    const mintingFee = BigNumber.from(((initRecord.mintingFeePercent ?? 0.05) * 100).toString());
    const liquidationReward = BigNumber.from(((initRecord.liquidationRewardPercent ?? 8) * 100).toString());

    const [ilDebtCeiling, ilTotalDebt, ilMintingFee, ilBorrowable] = await IL.viewILMetadata(tokenAddress);
    if (!(debtCeiling.eq(ilDebtCeiling) && mintingFee.eq(ilMintingFee))) {
      targetTokens.push(tokenAddress);
      debtCeilings.push(debtCeiling);
      feesPer10k.push(mintingFee);
      liquidationRewardsPer10k.push(liquidationReward);

      console.log(`added ${tokenName} at ${tokenAddress}`);
    } else {
      console.log(`skipped ${tokenName} at ${tokenAddress}`);
    }
  }
  const args = [
    targetTokens,
    debtCeilings,
    feesPer10k,
    liquidationRewardsPer10k,
    (await deployments.get('IsolatedLendingLiquidation')).address,
    roles.address
  ];

  if (targetTokens.length > 0) {
    const TokenActivation = await deploy('TokenActivation', {
      from: deployer,
      args,
      log: true
    });

    const tx = await dC.executeAsOwner(TokenActivation.address);
    console.log(`Executing token activation: ${tx.hash}`);
    await tx.wait();
  }
};

deploy.tags = ['TokenActivation', 'base'];
deploy.dependencies = [
  'DependencyController',
  'OracleRegistry',
  'TwapOracle',
  'ChainlinkOracle',
  'EquivalentScaledOracle',
  'ProxyOracle',
  'TwapOracle',
  'UniswapV2LPTOracle',
  'IsolatedLendingLiquidation'
];
deploy.runAtTheEnd = true;
export default deploy;

async function collectAllOracleCalls(hre: HardhatRuntimeEnvironment, tokensInQuestion: [string, string][]) {
  type OracleActivationArgs = {
    tokens: string[];
    pegCurrencies: string[];
    borrowables: BigNumber[];
    primaries: boolean[];
    data: string[];
  };
  const oracleActivationArgs: Record<string, OracleActivationArgs> = {};

  const tokenAddresses = Object.fromEntries(tokensInQuestion);
  async function processOracleCalls(oracle: OracleConfig, tokenName: string, tokenAddress: string, primary: boolean) {
    const initRecord = tokenInitRecords[tokenName];

    const [oracleName, args] = await oracle(true, tokenAddress, initRecord, tokenAddresses, hre);
    const oracleContract = await hre.ethers.getContractAt(oracleName, (await hre.deployments.get(oracleName)).address);

    const [matches, abiEncoded] = await oracleContract.encodeAndCheckOracleParams(...args);

    if (!matches) {
      if (!(oracleContract.address in oracleActivationArgs)) {
        oracleActivationArgs[oracleContract.address] = {
          tokens: [],
          pegCurrencies: [],
          borrowables: [],
          primaries: [],
          data: []
        };
      }

      // TODO: check col ratio is matching!

      const oracleActivationState = oracleActivationArgs[oracleContract.address];
      const borrowable = BigNumber.from(((initRecord.borrowablePercent ?? 60) * 100).toString());

      oracleActivationState.tokens.push(tokenAddress);
      oracleActivationState.pegCurrencies.push(args[1]);
      oracleActivationState.borrowables.push(borrowable);
      oracleActivationState.primaries.push(primary);
      oracleActivationState.data.push(abiEncoded);
    }
  }

  for (const [tokenName, tokenAddress] of tokensInQuestion) {
    const initRecord = tokenInitRecords[tokenName];
    for (const [additionalTokenName, additionalOracle] of initRecord.additionalOracles ?? []) {
      // TODO handle intermediary tokens that may not show up in the main list?
      await processOracleCalls(additionalOracle, additionalTokenName, tokenAddresses[additionalTokenName], false);
    }
    await processOracleCalls(initRecord.oracle, tokenName, tokenAddress, true);
  }

  return oracleActivationArgs;
}

////////////////////////////////////////////
// LP TOKEN STUFF

const factoriesPerNetwork: Record<string, Record<string, string>> = {
  hardhat: {
    traderJoe: '0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10',
    pangolin: '0xefa94DE7a4656D787667C749f7E1223D71E9FD88'
  },
  avalanche: {
    traderJoe: '0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10',
    pangolin: '0xefa94DE7a4656D787667C749f7E1223D71E9FD88'
  }
};

export const masterChefsPerNetwork: Record<string, Record<string, string>> = {
  hardhat: {
    traderJoe: '0xd6a4F121CA35509aF06A0Be99093d08462f53052'
  },
  avalanche: {
    traderJoe: '0xd6a4F121CA35509aF06A0Be99093d08462f53052'
  }
};

// Iterate over tokens per network
// Find all their pairs in all the factories, involving them and reference currencies
// set them up with (by default) one-sided LPT oracles, based on the reference currency
// cache those addresses in a JSON file

const pairAnchors = ['WETHe', 'WAVAX', 'USDCe'];

function generatePairsByNetwork(networkName: string): [[string, string], [string, string]][] {
  const tokenAddresses = tokensPerNetwork[networkName];
  const anchors: [string, string][] = pairAnchors
    .map(name => [name, tokenAddresses[name]])
    .filter(([_, address]) => address) as [string, string][];
  return Object.entries(tokenAddresses).flatMap(([ticker, address]) =>
    anchors.flatMap(([anchorTicker, anchorAddress]) =>
      anchorTicker == ticker
        ? []
        : [[[anchorTicker, ticker] as [string, string], sortAddresses(address, anchorAddress)]]
    )
  );
}

export type LPTokenRecord = {
  addresses: [string, string];
  pairAddress?: string;
  pid?: number;
  stakingContract?: string;
  anchorName: string;
};

export type LPTokensByAMM = Record<string, Record<string, Record<string, LPTokenRecord>>>;
export let lpTokensByAMM: LPTokensByAMM = {};

async function gatherLPTokens(hre: HardhatRuntimeEnvironment): Promise<LPTokensByAMM> {
  const factories = factoriesPerNetwork[hre.network.name];
  const masterChefs = masterChefsPerNetwork[hre.network.name];
  const pairsByNetwork = generatePairsByNetwork(hre.network.name);
  const stakingContracts = getPangolinStakingContracts(hre);

  const lpTokensPath = path.join(__dirname, '../build/lptokens.json');
  const masterChefCachePath = path.join(__dirname, '../build/masterchefcache.json');
  if (fs.existsSync(lpTokensPath)) {
    lpTokensByAMM = JSON.parse((await fs.promises.readFile(lpTokensPath)).toString());
  }
  let masterChefCache: Record<string, string[]> = {};
  if (fs.existsSync(masterChefCachePath)) {
    masterChefCache = JSON.parse((await fs.promises.readFile(masterChefCachePath)).toString());
  }

  const chainId = await hre.getChainId();
  if (!lpTokensByAMM[chainId]) {
    lpTokensByAMM[chainId] = {};
  }
  for (const [factoryName, factoryAddress] of Object.entries(factories)) {
    const lps: Record<string, LPTokenRecord> = lpTokensByAMM[chainId][factoryName] ?? {};

    const factory = await hre.ethers.getContractAt(IUniswapV2Factory.abi, factoryAddress);

    const currentCache = masterChefCache[factoryName] ?? [];

    if (factoryName in masterChefs) {
      const masterChef = await hre.ethers.getContractAt(IMasterChef.abi, masterChefs[factoryName]);
      const curMasterChefLen = (await masterChef.poolLength()).toNumber();
      for (let i = currentCache.length; curMasterChefLen > i; i++) {
        currentCache.push((await masterChef.poolInfo(i)).lpToken);
      }

      masterChefCache[factoryName] = currentCache;
    }

    const pidByLPT = Object.fromEntries(currentCache.map((lpt, pid) => [lpt, pid]));

    for (const [tickers, addresses] of pairsByNetwork) {
      const jointTicker = `${factoryName}-${tickers.join('-')}`;
      let pairAddress: string | undefined = await factory.getPair(addresses[0], addresses[1]);
      if (pairAddress === hre.ethers.constants.AddressZero) {
        pairAddress = undefined;
      }

      const pid: number | undefined = pairAddress ? pidByLPT[pairAddress] : undefined;

      let stakingContract: string;

      if (
        factoryName === 'pangolin' &&
        addresses[0] in stakingContracts &&
        addresses[1] in stakingContracts[addresses[0]]
      ) {
        stakingContract = stakingContracts[addresses[0]][addresses[1]];
      }

      if (
        !lps[jointTicker] ||
        !(lps[jointTicker].pairAddress === pairAddress) ||
        !(lps[jointTicker].pid === pid) ||
        !(lps[jointTicker].stakingContract === stakingContract)
      ) {
        lps[jointTicker] = {
          addresses,
          pairAddress,
          pid,
          anchorName: tickers[0],
          stakingContract
        };
      }
    }
    lpTokensByAMM[chainId][factoryName] = lps;
  }

  await fs.promises.writeFile(masterChefCachePath, JSON.stringify(masterChefCache, null, 2));
  await fs.promises.writeFile(lpTokensPath, JSON.stringify(lpTokensByAMM, null, 2));

  return lpTokensByAMM;
}

function sortAddresses(a1: string, a2: string): [string, string] {
  return a1.toLowerCase() < a2.toLocaleLowerCase()
    ? [a1.toLocaleLowerCase(), a2.toLocaleLowerCase()]
    : [a2.toLocaleLowerCase(), a1.toLocaleLowerCase()];
}

function UniswapV2LPTConfig(anchorName: string): OracleConfig {
  return async (_primary, tokenAddress, _record, allTokens, hre) => [
    'UniswapV2LPTOracle',
    [tokenAddress, (await hre.deployments.get('Stablecoin')).address, allTokens[anchorName]]
  ];
}

const LPT_DEBTCEIL_DEFAULT = 1000;

async function augmentInitRecordsWithLPT(hre: HardhatRuntimeEnvironment): Promise<[string, string][]> {
  const lpTokensByAMM = await gatherLPTokens(hre);
  const result: [string, string][] = [];

  // TODO: differentiate stable / non-stable fees

  for (const [_amm, lptokens] of Object.entries(lpTokensByAMM[await hre.getChainId()])) {
    for (const [jointTicker, lpTokenRecord] of Object.entries(lptokens)) {
      if (lpTokenRecord.pid || lpTokenRecord.stakingContract) {
        tokenInitRecords[jointTicker] = {
          debtCeiling: LPT_DEBTCEIL_DEFAULT,
          oracle: UniswapV2LPTConfig(lpTokenRecord.anchorName),
          borrowablePercent: 70,
          liquidationRewardPercent: 10
        };

        result.push([jointTicker, lpTokenRecord.pairAddress!]);
      }
    }
  }

  return result;
}

function getPangolinStakingContracts(hre: HardhatRuntimeEnvironment): Record<string, Record<string, string>> {
  const tokenAddresses = tokensPerNetwork[hre.network.name];

  const stakingContracts: Record<string, Record<string, string>> = {};
  for (const { tokens, stakingRewardAddress } of Object.values(pngrewards)) {
    const [token0, token1] = tokens;
    if (token0 in tokenAddresses && token1 in tokenAddresses) {
      const addresses = sortAddresses(tokenAddresses[token0], tokenAddresses[token1]);
      stakingContracts[addresses[0]] = addresses[0] in stakingContracts ? stakingContracts[addresses[0]] : {};
      stakingContracts[addresses[0]][addresses[1]] = stakingRewardAddress;
    }
  }
  return stakingContracts;
}
