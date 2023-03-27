// iterate over, group them up
// test their parameters all over the place?
// perhaps another central registry? -- to make idempotency easier

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { BigNumber } from '@ethersproject/bignumber';
import { parseEther, parseUnits } from '@ethersproject/units';
import IUniswapV2Factory from '@uniswap/v2-core/build/IUniswapV2Factory.json';
import IMasterChefJoeV3 from '../build/artifacts/interfaces/IMasterChefJoeV3.sol/IMasterChefJoeV3.json';
import IMiniChefV2 from '../build/artifacts/interfaces/IMiniChefV2.sol/IMiniChefV2.json';
import path from 'path';
import * as fs from 'fs';
import { net } from './Roles';
import { getAddress } from '@ethersproject/address';

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
    YAK: '0x59414b3089ce2AF0010e7523Dea7E2b35d776ec7',
    QI: '0x8729438EB15e2C8B576fCc6AeCdA6A148776C0F5',
    // XAVA: '0xd1c3f94DE7e5B45fa4eDBBA472491a9f4B166FC4',
    JOE: '0x6e84a6216ea6dacc71ee8e6b0a5b7322eebc0fdd',
    USDCe: '0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664',
    USDC: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E',
    DAIe: '0xd586e7f844cea2f87f50152665bcbc2c279d8d70',
    BTCb: '0x152b9d0FdC40C096757F570A51E494bd4b943E50',
    WBTCe: '0x50b7545627a5162f82a992c33b87adc75187b218',
    MAXI: '0x7C08413cbf02202a1c13643dB173f2694e0F73f0',
    wsMAXI: '0x2148D1B21Faa7eb251789a51B404fc063cA6AAd6',
    xJOE: '0x57319d41f71e81f3c65f2a47ca4e001ebafd4f33',
    PTP: '0x22d4002028f537599bE9f666d1c4Fa138522f9c8',
    'JPL-WAVAX-JOE': '0x454E67025631C065d3cFAD6d71E6892f74487a15',
    sAVAX: '0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE',
    yyAvax: '0xF7D9281e8e363584973F946201b82ba72C965D27',
    'JPL-WAVAX-PTP': '0xCDFD91eEa657cc2701117fe9711C9a4F61FEED23',
    'JPL-CAI-WAVAX': '0xE5e9d67e93aD363a50cABCB9E931279251bBEFd0',
    fsGLP: '0x9e295B5B976a184B14aD8cd72413aD846C299660'
  },
  avalanche: {
    WAVAX: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
    // WETHe: '0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB',
    PNG: '0x60781C2586D68229fde47564546784ab3fACA982',
    USDTe: '0xc7198437980c041c805A1EDcbA50c1Ce5db95118',
    YAK: '0x59414b3089ce2AF0010e7523Dea7E2b35d776ec7',
    QI: '0x8729438EB15e2C8B576fCc6AeCdA6A148776C0F5',
    // XAVA: '0xd1c3f94DE7e5B45fa4eDBBA472491a9f4B166FC4',

    JOE: '0x6e84a6216ea6dacc71ee8e6b0a5b7322eebc0fdd',
    USDCe: '0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664',
    USDC: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E',
    DAIe: '0xd586e7f844cea2f87f50152665bcbc2c279d8d70',
    BTCb: '0x152b9d0FdC40C096757F570A51E494bd4b943E50',
    WBTCe: '0x50b7545627a5162f82a992c33b87adc75187b218',
    MAXI: '0x7C08413cbf02202a1c13643dB173f2694e0F73f0',
    wsMAXI: '0x2148D1B21Faa7eb251789a51B404fc063cA6AAd6',
    xJOE: '0x57319d41f71e81f3c65f2a47ca4e001ebafd4f33',
    PTP: '0x22d4002028f537599bE9f666d1c4Fa138522f9c8',
    'JPL-WAVAX-JOE': '0x454E67025631C065d3cFAD6d71E6892f74487a15',
    'JPL-WAVAX-USDCe': '0xa389f9430876455c36478deea9769b7ca4e3ddb1',
    'JPL-WAVAX-USDTe': '0xed8cbd9f0ce3c6986b22002f03c6475ceb7a6256',
    'JPL-WAVAX-WBTCe': '0xd5a37dc5c9a396a03dd1136fc76a1a02b1c88ffa',
    sAVAX: '0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE',
    yyAvax: '0xF7D9281e8e363584973F946201b82ba72C965D27',
    'JPL-WAVAX-PTP': '0xCDFD91eEa657cc2701117fe9711C9a4F61FEED23',
    'JPL-CAI-WAVAX': '0xE5e9d67e93aD363a50cABCB9E931279251bBEFd0',
    fsGLP: '0x9e295B5B976a184B14aD8cd72413aD846C299660'
  }
};

export const chosenTokens: Record<string, Record<string, boolean>> = {
  hardhat: {
    WAVAX: true,
    // PNG: true,
    USDTe: true,
    BTCb: true,
    JOE: true,
    USDCe: true,
    // YAK: true,
    // QI: true,
    // MORE: true,

    // 'JPL-WAVAX-JOE': true,
    // 'JPL-WAVAX-USDTe': true,

    // 'PGL-WAVAX-PNG': true,
    // 'PGL-WETHe-WAVAX': true,
    // 'PGL-WAVAX-USDTe': true,
    // 'JPL-WAVAX-PTP': true,
    'JPL-CAI-WAVAX': true,
    // wsMAXI: true,
    // xJOE: true,
    // MAXI: true,
    sAVAX: true,
    yyAvax: true,
    fsGLP: true,
  },
  avalanche: {
    // YAK: false,
    WAVAX: true,
    // PNG: true,
    // USDTe: true,
    // JOE: true,

    // 'JPL-WAVAX-JOE': true,

    // 'JPL-WAVAX-USDCe': true,
    // 'JPL-WAVAX-USDTe': true,
    // 'JPL-WAVAX-WBTCe': true,
    // 'JPL-WAVAX-PTP': true,
    // wsMAXI: true,
    'JPL-CAI-WAVAX': true,
    BTCb: true,
    JOE: true,
    // xJOE: true,
    // QI: true,
    DAIe: true,
    USDCe: true,
    sAVAX: true,
    yyAvax: true,
    fsGLP: true
    // 'JPL-WAVAX-USDTe': true,

    // 'PGL-WAVAX-PNG': true,
    // 'PGL-WETHe-WAVAX': true,
    // 'PGL-WAVAX-USDTe': true
  }
}

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

function EquivalentConfig(tokenPrice?: string, pegCurrency?: string): OracleConfig {
  return async (primary, tokenAddress, record, allTokens, hre) => [
    'EquivalentScaledOracle',
    [
      tokenAddress,
      pegCurrency ? allTokens[pegCurrency] : (await hre.deployments.get('Stablecoin')).address,
      parseUnits(tokenPrice ?? '1', record.decimals ?? 18),
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

function WrapperConfig(wrappedCurrency: string): OracleConfig {
  return async (_primary, tokenAddress, record, allTokens, hre) => {
    return ['WrapperTokenOracle', [tokenAddress, allTokens[wrappedCurrency]]];
  };
}

const LPT_DEBTCEIL_DEFAULT = 1000000;

function lptRecord(anchor: string) {
  return {
    debtCeiling: LPT_DEBTCEIL_DEFAULT,
    oracle: UniswapV2LPTConfig(anchor),
    borrowablePercent: 70,
    liquidationRewardPercent: 12
  };
}

export const tokenInitRecords: Record<string, TokenInitRecord> = {
  fsGLP: {
    oracle: async (_primary, tokenAddress, _record, allTokens, hre) => ['fsGLPOracle', [tokenAddress, (await hre.deployments.get('Stablecoin')).address]],
    debtCeiling: 1000000,
    borrowablePercent: 70,
    liquidationRewardPercent: 5
  },
  PTP: {
    debtCeiling: 0,
    oracle: ProxyConfig('WAVAX'),
    additionalOracles: [['PTP', TraderTwapConfig('WAVAX')]],
    borrowablePercent: 0,
    liquidationRewardPercent: 10
  },
  sAVAX: {
    debtCeiling: 1000000,
    oracle: ProxyConfig('WAVAX'),
    additionalOracles: [
      [
        'sAVAX',
        async (_primary, tokenAddress, _record, allTokens, hre) => ['sAvaxOracle', [tokenAddress, allTokens.WAVAX]]
      ]
    ],
    borrowablePercent: 40,
    liquidationRewardPercent: 5
  },
  yyAvax: {
    debtCeiling: 200000,
    oracle: ProxyConfig('WAVAX'),
    additionalOracles: [
      [
        'yyAvax',
        async (_primary, tokenAddress, _record, allTokens, hre) => ['yyAvaxOracle', [tokenAddress, allTokens.WAVAX]]
      ]
    ],
    borrowablePercent: 60,
    liquidationRewardPercent: 6.5
  },
  'JPL-WAVAX-USDCe': lptRecord('WAVAX'),
  'JPL-WAVAX-USDTe': lptRecord('WAVAX'),
  'JPL-WAVAX-WBTCe': lptRecord('WAVAX'),
  'JPL-WAVAX-PTP': lptRecord('WAVAX'),
  'JPL-CAI-WAVAX': {
    debtCeiling: 100000,
    oracle: UniswapV2LPTConfig('WAVAX'),
    borrowablePercent: 60,
    liquidationRewardPercent: 10
  },
  MAXI: {
    oracle: ProxyConfig('DAIe'),
    debtCeiling: 0,
    additionalOracles: [['MAXI', TraderTwapConfig('DAIe')]]
  },
  wsMAXI: {
    debtCeiling: 300000,
    oracle: ProxyConfig('MAXI'),
    additionalOracles: [
      [
        'wsMAXI',
        async (_primary, tokenAddress, _record, allTokens, hre) => ['WsMAXIOracle', [tokenAddress, allTokens.MAXI]]
      ],
    ],
    borrowablePercent: 60,
    liquidationRewardPercent: 10,
    mintingFeePercent: 2
  },
  WAVAX: {
    oracle: ChainlinkConfig('0x0a77230d17318075983913bc2145db16c7366156'),
    debtCeiling: 1000000,
    additionalOracles: [['WAVAX', TraderTwapConfig('USDCe')]],
    borrowablePercent: 80,
    liquidationRewardPercent: 5
  },
  WETHe: {
    oracle: ChainlinkConfig('0x976b3d034e162d8bd72d6b9c989d545b839003b0'),
    debtCeiling: 1000000,
    additionalOracles: [['WETHe', TraderTwapConfig('USDCe')]],
    borrowablePercent: 80,
    liquidationRewardPercent: 10
  },
  WBTCe: {
    oracle: ChainlinkConfig('0x2779d32d5166baaa2b2b658333ba7e6ec0c65743'),
    debtCeiling: 1000000,
    additionalOracles: [['WBTCe', TraderTwapConfig('USDCe')]],
    borrowablePercent: 80,
    liquidationRewardPercent: 10
  },
  BTCb: {
    oracle: ChainlinkConfig('0x2779d32d5166baaa2b2b658333ba7e6ec0c65743'),
    debtCeiling: 1000000,
    decimals: 8,
    additionalOracles: [
      ['BTCb', TraderTwapConfig('WAVAX')],
      ['BTCb', ProxyConfig('WAVAX', 'USDCe')]
    ],
    borrowablePercent: 80,
    liquidationRewardPercent: 10,
  },
  USDC: {
    oracle: EquivalentConfig(),
    debtCeiling: 0,
    decimals: 6,
    borrowablePercent: 80,
    liquidationRewardPercent: 4
  },
  USDCe: {
    oracle: EquivalentConfig(),
    debtCeiling: 0,
    decimals: 6,
    borrowablePercent: 80,
    liquidationRewardPercent: 4
  },
  USDTe: {
    oracle: EquivalentConfig(),
    debtCeiling: 0,
    decimals: 6,
    borrowablePercent: 95,
    liquidationRewardPercent: 4
  },
  JOE: {
    oracle: ProxyConfig('USDCe'),
    debtCeiling: 20000,
    additionalOracles: [['JOE', TraderTwapConfig('USDCe')]],
    borrowablePercent: 70,
    liquidationRewardPercent: 10
  },
  PNG: {
    oracle: ProxyConfig('WAVAX'),
    debtCeiling: 1000001,
    additionalOracles: [['PNG', TraderTwapConfig('WAVAX')]],
    borrowablePercent: 60,
    liquidationRewardPercent: 10
  },
  DAIe: {
    oracle: EquivalentConfig(),
    debtCeiling: 0,
    decimals: 18,
    borrowablePercent: 80,
    liquidationRewardPercent: 4
  },
  QI: {
    oracle: ProxyConfig('WAVAX'),
    debtCeiling: 1000001,
    additionalOracles: [['QI', PngTwapConfig('WAVAX')]],
    borrowablePercent: 60,
    liquidationRewardPercent: 10
  },
  xJOE: {
    oracle: ProxyConfig('JOE'),
    debtCeiling: 0,
    additionalOracles: [['xJOE', WrapperConfig('JOE')]],
  },
  YAK: {
    oracle: ProxyConfig('WAVAX'),
    debtCeiling: 0,
    additionalOracles: [['YAK', TraderTwapConfig('WAVAX')]],
    borrowablePercent: 60,
    liquidationRewardPercent: 10
  },
  MORE: {
    oracle: ProxyConfig('WAVAX'),
    debtCeiling: 1000000,
    additionalOracles: [['MORE', TraderTwapConfig('WAVAX')]],
    borrowablePercent: 50,
    liquidationRewardPercent: 10
  },
};

const deploy: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
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

  const IL = await ethers.getContractAt('StableLending2', (await deployments.get('StableLending2')).address);

  const dC = await ethers.getContractAt(
    'DependencyController',
    (
      await deployments.get('DependencyController')
    ).address
  );

  const netname = net(network.name);
  tokensPerNetwork[netname].MORE = (await deployments.get('MoreToken')).address;

  const chosenOnes = chosenTokens[netname];
  const oracleTokensInQuestion: [string, string][] = [
    ...Array.from(Object.entries(tokensPerNetwork[netname])).concat(
      lptTokenAddresses.filter(([name, address]) => chosenOnes[name])
    )
  ];

  const tokensInQuestion = Array.from(Object.entries(tokensPerNetwork[netname]))
    .concat(lptTokenAddresses)
    .filter(([name, address]) => chosenOnes[name]);

  // first go over all the oracles
  const allOracleActivations = await collectAllOracleCalls(hre, oracleTokensInQuestion);

  // move proxy oracle to front to deal with some dependency ordering issues
  const ProxyO = (await deployments.get('ProxyOracle')).address;
  const oracleAddresses = [
    ...(ProxyO in allOracleActivations ? [ProxyO] : []),
    ...Object.keys(allOracleActivations).filter(address => address !== ProxyO)
  ];

  for (const oracleAddress of oracleAddresses) {
    const oArgs = allOracleActivations[oracleAddress];
    if (oArgs.tokens.length > 0) {
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
        log: true,
        skipIfAlreadyDeployed: false
      });

      console.log();
      console.log();
      console.log('##########################################');
      console.log();
      console.log('OracleActivation:');
      console.log(`Call ${dC.address} . execute ( ${OracleActivation.address} )`);
      console.log();
      console.log('##########################################');
      console.log();
      console.log();

      if (network.name === 'localhost') {
        const Roles = await ethers.getContractAt('Roles', roles.address);
        const currentOwner = await Roles.owner();

        let tx = await (await ethers.getSigner(deployer)).sendTransaction({ to: currentOwner, value: parseEther('1') });
        await tx.wait();

        const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
        await provider.send('hardhat_impersonateAccount', [currentOwner]);
        const signer = provider.getSigner(currentOwner);
        // await network.provider.request({
        //   method: 'hardhat_impersonateAccount',
        //   params: [currentOwner]
        // });
        // const signer = await ethers.provider.getSigner(currentOwner);

        if ((await ethers.provider.getCode(OracleActivation.address)) !== '0x') {
          tx = await dC.connect(signer).executeAsOwner(OracleActivation.address);
          console.log(`Running oracle activation: ${tx.hash}`);
          await tx.wait();
        }
      } else if (network.name === 'hardhat') {
        if ((await ethers.provider.getCode(OracleActivation.address)) !== '0x') {
          const tx = await dC.executeAsOwner(OracleActivation.address, { gasLimit: 8000000 });
          console.log(`Executing oracle activation for ${oracleAddress}: ${tx.hash}`);
          await tx.wait();
        }
      }
    }
  }

  for (const [tokenName, tokenAddress] of tokensInQuestion) {
    const initRecord = tokenInitRecords[tokenName];
    const debtCeiling = parseEther(initRecord.debtCeiling.toString());
    const mintingFee = BigNumber.from(((initRecord.mintingFeePercent ?? 0.1) * 100).toString());
    const liquidationReward = BigNumber.from((((initRecord.liquidationRewardPercent ?? 8) - 1.5) * 100).toString());

    let add = false;
    try {
      const [ilDebtCeiling, ilTotalDebt, ilMintingFee, ilBorrowable] = await IL.viewILMetadata(tokenAddress);
      add = !(debtCeiling.eq(ilDebtCeiling) && mintingFee.eq(ilMintingFee));
    } catch (e) {
      add = true;
    }
    if (add) {
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
    (await deployments.get('StableLendingLiquidation')).address,
    (await deployments.get('StableLending2Liquidation')).address,
    roles.address
  ];

  if (targetTokens.length > 0) {
    const TokenActivation = await deploy('TokenActivation', {
      from: deployer,
      args,
      log: true,
      skipIfAlreadyDeployed: false
    });
    console.log();
    console.log();
    console.log('##########################################');
    console.log();
    console.log('TokenActivation:');
    console.log(`Call ${dC.address} . execute ( ${TokenActivation.address} )`);
    console.log();
    console.log('##########################################');
    console.log();
    console.log();

    if (network.name === 'localhost') {
      const Roles = await ethers.getContractAt('Roles', roles.address);
      const currentOwner = await Roles.owner();

      if (getAddress(currentOwner) !== getAddress(deployer)) {
        console.log('Impersonating owner');

        let tx = await (
          await ethers.getSigner(deployer)
        ).sendTransaction({ to: currentOwner, value: parseEther('1') });
        await tx.wait();

        const provider = new ethers.providers.JsonRpcProvider(
          'http://localhost:8545'
        );
        await provider.send('hardhat_impersonateAccount', [currentOwner]);
        const signer = provider.getSigner(currentOwner);
        // await network.provider.request({
        //   method: 'hardhat_impersonateAccount',
        //   params: [currentOwner]
        // });
        // const signer = await ethers.provider.getSigner(currentOwner);

        tx = await dC.connect(signer).executeAsOwner(TokenActivation.address);
        console.log(`Running token activation: ${tx.hash}`);
        await tx.wait();
      }
    } else if (network.name === 'hardhat') {
      if ((await ethers.provider.getCode(TokenActivation.address)) !== '0x') {
        const tx = await dC.executeAsOwner(TokenActivation.address, {
          gasLimit: 8000000,
        });
        console.log(`Executing token activation: ${tx.hash}`);
        await tx.wait();
      }
    }
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
  'CurvePool',
  'CurveLPTOracle',
  'StableLending',
  'StableLending2',
  'StableLendingStableLiquidation',
  'StableLending2Liquidation',
  'WrapNativeStableLending2',
  'MoreToken',
  'ContractManagement',
];
deploy.runAtTheEnd = true;
export default deploy;

async function collectAllOracleCalls(
  hre: HardhatRuntimeEnvironment,
  tokensInQuestion: [string, string][]
) {
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
    const extantBorrowable = initRecord.borrowablePercent;
    // const extantBorrowable = (await (await hre.ethers.getContractAt('OracleRegistry', (await hre.deployments.get('OracleRegistry')).address)).borrowablePer10ks(tokenAddress)).mul(100).toNumber() / 10000;

    if (
      !matches ||
      Math.abs(extantBorrowable - initRecord.borrowablePercent) > 3
    ) {
      if (!(oracleContract.address in oracleActivationArgs)) {
        oracleActivationArgs[oracleContract.address] = {
          tokens: [],
          pegCurrencies: [],
          borrowables: [],
          primaries: [],
          data: [],
        };
      }

      const oracleActivationState =
        oracleActivationArgs[oracleContract.address];
      const rawBorrowableNum = initRecord.borrowablePercent ?? 0;
      const prettyColRatio = 5 * Math.round((100 * 100) / rawBorrowableNum / 5);
      const prettyBorrowableNum = Math.round((10000 * 100) / prettyColRatio);
      const borrowable = BigNumber.from(prettyBorrowableNum.toString());

      oracleActivationState.tokens.push(tokenAddress);
      oracleActivationState.pegCurrencies.push(args[1]);
      oracleActivationState.borrowables.push(borrowable);
      oracleActivationState.primaries.push(primary);
      oracleActivationState.data.push(abiEncoded);

      console.log(
        `Added ${tokenName} to ${oracleName} for initialization with ~${rawBorrowableNum}% borrowable and args: ${args}`
      );
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
    JPL: '0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10',
    PGL: '0xefa94DE7a4656D787667C749f7E1223D71E9FD88'
  },
  avalanche: {
    JPL: '0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10',
    PGL: '0xefa94DE7a4656D787667C749f7E1223D71E9FD88'
  }
};

export const masterChefsPerNetwork: Record<string, Record<string, string>> = {
  hardhat: {
    JPL: '0xd6a4F121CA35509aF06A0Be99093d08462f53052'
  },
  avalanche: {
    JPL: '0xd6a4F121CA35509aF06A0Be99093d08462f53052'
  }
};

export const miniChefsPerNetwork: Record<string, Record<string, string>> = {
  hardhat: {
    PGL: '0x1f806f7C8dED893fd3caE279191ad7Aa3798E928'
  },
  avalanche: {
    PGL: '0x1f806f7C8dED893fd3caE279191ad7Aa3798E928'
  }
};

// Iterate over tokens per network
// Find all their pairs in all the factories, involving them and reference currencies
// set them up with (by default) one-sided LPT oracles, based on the reference currency
// cache those addresses in a JSON file

const pairAnchors = ['WETHe', 'WAVAX', 'USDCe'];

function generatePairsByNetwork(
  networkName: string
): [[string, string], [string, string]][] {
  const tokenAddresses = tokensPerNetwork[networkName];
  const anchors: [string, string][] = pairAnchors
    .map((name) => [name, tokenAddresses[name]])
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
  const netname = net(hre.network.name);
  const factories = factoriesPerNetwork[netname];
  const masterChefs = masterChefsPerNetwork[netname];
  const miniChefs = miniChefsPerNetwork[netname];
  const pairsByNetwork = generatePairsByNetwork(netname);
  // const stakingContracts = getPangolinStakingContracts(hre);

  const lpTokensPath = path.join(__dirname, '../build/lptokens.json');
  const masterChefCachePath = path.join(
    __dirname,
    '../build/masterchefcache.json'
  );
  if (fs.existsSync(lpTokensPath)) {
    lpTokensByAMM = JSON.parse(
      (await fs.promises.readFile(lpTokensPath)).toString()
    );
  }
  let masterChefCache: Record<string, string[]> = {};
  if (fs.existsSync(masterChefCachePath)) {
    masterChefCache = JSON.parse(
      (await fs.promises.readFile(masterChefCachePath)).toString()
    );
  }

  const chainId = await hre.getChainId();
  if (!lpTokensByAMM[chainId]) {
    lpTokensByAMM[chainId] = {};
  }
  for (const [factoryName, factoryAddress] of Object.entries(factories)) {
    const lps: Record<string, LPTokenRecord> =
      lpTokensByAMM[chainId][factoryName] ?? {};

    const factory = await hre.ethers.getContractAt(
      IUniswapV2Factory.abi,
      factoryAddress
    );

    const currentCache = masterChefCache[factoryName] ?? [];

    const isMasterChef = factoryName in masterChefs;
    if (isMasterChef || factoryName in miniChefs) {
      const chef = isMasterChef
        ? await hre.ethers.getContractAt(IMasterChefJoeV3.abi, masterChefs[factoryName])
        : await hre.ethers.getContractAt(IMiniChefV2.abi, miniChefs[factoryName]);

      const curChefLen = (await chef.poolLength()).toNumber();
      for (let i = currentCache.length; curChefLen > i; i++) {
        const token = isMasterChef ? (await chef.poolInfo(i)).lpToken : await chef.lpToken(i);
        currentCache.push(token);
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

      // if (factoryName === 'PGL' && addresses[0] in stakingContracts && addresses[1] in stakingContracts[addresses[0]]) {
      //   stakingContract = stakingContracts[addresses[0]][addresses[1]];
      // }

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

  // await fs.promises.writeFile(masterChefCachePath, JSON.stringify(masterChefCache, null, 2));
  // comment out the lptokens.json file generation
  // to update the LP tokens, you need to change that manually in the frontend code.
  // await fs.promises.writeFile(lpTokensPath, JSON.stringify(lpTokensByAMM, null, 2));

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

async function augmentInitRecordsWithLPT(hre: HardhatRuntimeEnvironment): Promise<[string, string][]> {
  const lpTokensByAMM = await gatherLPTokens(hre);
  const result: [string, string][] = [];

  // TODO: differentiate stable / non-stable fees

  for (const [_amm, lptokens] of Object.entries(lpTokensByAMM[await hre.getChainId()])) {
    for (const [jointTicker, lpTokenRecord] of Object.entries(lptokens)) {
      if (typeof lpTokenRecord.pid === 'number' || lpTokenRecord.stakingContract) {
        tokenInitRecords[jointTicker] = {
          debtCeiling: LPT_DEBTCEIL_DEFAULT,
          oracle: UniswapV2LPTConfig(lpTokenRecord.anchorName),
          borrowablePercent: 70,
          liquidationRewardPercent: 12
        };

        result.push([jointTicker, lpTokenRecord.pairAddress!]);
      }
    }
  }

  return result;
}

// function getPangolinStakingContracts(hre: HardhatRuntimeEnvironment): Record<string, Record<string, string>> {
//   const tokenAddresses = tokensPerNetwork[hre.network.name];

//   const stakingContracts: Record<string, Record<string, string>> = {};
//   for (const { tokens, stakingRewardAddress } of Object.values(pngrewards)) {
//     const [token0, token1] = tokens;
//     if (token0 in tokenAddresses && token1 in tokenAddresses) {
//       const addresses = sortAddresses(tokenAddresses[token0], tokenAddresses[token1]);
//       stakingContracts[addresses[0]] = addresses[0] in stakingContracts ? stakingContracts[addresses[0]] : {};
//       stakingContracts[addresses[0]][addresses[1]] = stakingRewardAddress;
//     }
//   }
//   return stakingContracts;
// }
