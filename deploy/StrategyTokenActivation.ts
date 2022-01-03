import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { chosenTokens, LPTokensByAMM, tokensPerNetwork } from './TokenActivation';
import path from 'path';
import * as fs from 'fs';
import IERC20 from '@openzeppelin/contracts/build/contracts/IERC20.json';

const SimpleHoldingStrategy = { strategy: 'SimpleHoldingStrategy', args: [500] };
const TraderJoeMasterChefStrategy = 'TraderJoeMasterChefStrategy';
const PangolinMiniChefStrategy = 'PangolinMiniChefStrategy';
const YYAVAXStrategy = {
  strategy: 'YieldYakAVAXStrategy',
  args: ['0x8B414448de8B609e96bd63Dcf2A8aDbd5ddf7fdd']
};

type StrategyConfig = {
  strategy: string;
  args: any[];
};

const strategiesPerNetwork: Record<string, Record<string, StrategyConfig[]>> = {
  hardhat: {
    // USDCe: [],
    // WETHe: [],
    WAVAX: [YYAVAXStrategy],
    USDTe: [SimpleHoldingStrategy],
    PNG: [],
    JOE: [SimpleHoldingStrategy]
  },
  avalanche: {
    // USDCe: [],
    // WETHe: [],
    WAVAX: [YYAVAXStrategy],
    USDTe: [],
    PNG: [],
    JOE: [],
    QI: []
  }
};

const lptStrategies: Record<string, Record<string, string>> = {
  hardhat: {
    JPL: TraderJoeMasterChefStrategy,
    PGL: PangolinMiniChefStrategy
  },
  avalanche: {
    JPL: TraderJoeMasterChefStrategy,
    PGL: PangolinMiniChefStrategy
  }
};

const YYStrats = {
  USDTe: '0x07B0E11D80Ccf75CB390c9Be6c27f329c119095A',
  QI: '0xbF5bFFbf7D94D3B29aBE6eb20089b8a9E3D229f7',
  JOE: '0x3A91a592A06390ca7884c4D9dd4CBA2B4B7F36D1',
  PNG: '0x19707F26050Dfe7eb3C1b36E49276A088cE98752',
  YAK: '0x0C4684086914D5B1525bf16c62a0FF8010AB991A'
};

// TODO: choice of strategies, tokens and deposit limits must be done by hand

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // switch the below if you want YY strategies for your LPT
  await augmentStrategiesPerNetworkWithYY(hre);
  await augmentStrategiesPerNetworkWithLPT(hre);

  const tokenStrategies = Object.entries(strategiesPerNetwork[hre.network.name]);

  const STEP = 10;
  for (let i = 0; tokenStrategies.length > i; i += 10) {
    await runDeploy(tokenStrategies.slice(i, i + STEP), hre);
  }
};

async function runDeploy(tokenStrategies: [string, StrategyConfig[]][], hre: HardhatRuntimeEnvironment) {
  const { getNamedAccounts, deployments, getChainId, getUnnamedAccounts, network, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const tokenAddresses = tokensPerNetwork[network.name];

  const dC = await ethers.getContractAt(
    'DependencyController',
    (
      await deployments.get('DependencyController')
    ).address
  );

  const args: [string[], string[], string[], string] = [[], [], [], roles.address];
  for (const [tokenName, strategies] of tokenStrategies) {
    const tokenAddress = tokenAddresses[tokenName];

    for (const strategy of strategies) {
      const strategyAddress = (await deployments.get(strategy.strategy)).address;

      const [isEnabled, tokenData] = await (
        await ethers.getContractAt(strategy.strategy, strategyAddress)
      ).checkApprovedAndEncode(tokenAddress, ...strategy.args);

      if (!isEnabled) {
        args[0].push(tokenAddress);
        args[1].push(strategyAddress);
        args[2].push(tokenData);

        console.log(`addded ${tokenName} for strategy ${strategy.strategy}`);
      }
    }
  }

  if (args[0].length > 0) {
    const StrategyTokenActivation = await deploy('StrategyTokenActivation', {
      from: deployer,
      args,
      log: true
    });

    const tx = await dC.executeAsOwner(StrategyTokenActivation.address, { gasLimit: 8000000 });
    console.log(`Executing strategy token activation as owner: ${tx.hash}`);
    await tx.wait();
  }
}

deploy.tags = ['StrategyTokenActivation', 'base'];
deploy.dependencies = ['TokenActivation', 'DependencyController'];
deploy.runAtTheEnd = true;
export default deploy;

// For MasterChef:
// per each masterchef pull all the PIDs and cache in a JSON file
// go through all the pairs generated per DEX
// look up their addresses in that PID cache
// activate if necessary

async function augmentStrategiesPerNetworkWithLPT(hre: HardhatRuntimeEnvironment) {
  const networkName = hre.network.name;
  const chainId = await hre.getChainId();
  const tokenStrategies = strategiesPerNetwork[networkName];

  const lpTokensPath = path.join(__dirname, '../build/lptokens.json');
  const lpTokensByAMM: LPTokensByAMM = JSON.parse((await fs.promises.readFile(lpTokensPath)).toString());

  const chosenOnes = chosenTokens[networkName];
  for (const [amm, strategyName] of Object.entries(lptStrategies[networkName])) {
    const lpRecords = lpTokensByAMM[chainId][amm];

    for (const [jointTicker, lpRecord] of Object.entries(lpRecords)) {
      if (chosenOnes[jointTicker]) {
        if (typeof lpRecord.pid === 'number') {
          const depositLimit = (
            await (await hre.ethers.getContractAt(IERC20.abi, lpRecord.pairAddress)).totalSupply()
          ).div(10);
          tokenStrategies[jointTicker] = [{ strategy: strategyName, args: [lpRecord.pid] }];
          tokensPerNetwork[networkName][jointTicker] = lpRecord.pairAddress!;
        } else if (lpRecord.stakingContract) {
          const depositLimit = (
            await (await hre.ethers.getContractAt(IERC20.abi, lpRecord.pairAddress)).totalSupply()
          ).div(10);
          tokenStrategies[jointTicker] = [{ strategy: strategyName, args: [lpRecord.stakingContract] }];
          tokensPerNetwork[networkName][jointTicker] = lpRecord.pairAddress!;
        }
      }
    }
  }
}

async function augmentStrategiesPerNetworkWithYY(hre: HardhatRuntimeEnvironment) {
  const tokenStrategies = strategiesPerNetwork[hre.network.name];
  console.log(`network name: ${hre.network.name}`);
  if (['avalanche', 'localhost', 'hardhat', 'local'].includes(hre.network.name)) {
    const chosenOnes = chosenTokens[hre.network.name];

    const { token2strategy } = await getYYStrategies(hre);
    for (const [tokenName, tokenAddress] of Object.entries(tokensPerNetwork[hre.network.name])) {
      const stratAddress = token2strategy[tokenAddress];
      if (stratAddress && chosenOnes[tokenName]) {
        const depositLimit = (await (await hre.ethers.getContractAt(IERC20.abi, stratAddress)).totalSupply()).div(10);
        tokenStrategies[tokenName] = [
          { strategy: 'YieldYakStrategy', args: [stratAddress] },
          ...(tokenStrategies[tokenName] ?? [])
        ];
      }
    }
  }
}

async function getYYStrategies(hre: HardhatRuntimeEnvironment) {
  const token2strategy: Record<string, string> = {};
  const tokenAddresses = tokensPerNetwork[hre.network.name];

  Object.entries(YYStrats).forEach(([tokenName, stratAddress]) => {
    token2strategy[tokenAddresses[tokenName]] = stratAddress;
  });

  return { token2strategy };
}

// const yyAPI = 'https://staging-api-dot-avalanche-304119.ew.r.appspot.com/apys';
// async function getYYStrategies(hre: HardhatRuntimeEnvironment) {
//   console.log(`Getting yy strategy data`);
//   const yyStratPath = path.join(__dirname, '../build/yy-strategies.json');
//   if (fs.existsSync(yyStratPath)) {
//     console.log(`Reading YY strategies from ${yyStratPath}`);
//     return JSON.parse((await fs.promises.readFile(yyStratPath)).toString());
//   } else {
//     console.log(`Fetching YY strategies from API`);
//     const response = await fetch(yyAPI);

//     const token2strategy: Record<string, string> = {};
//     const strategy2timestamp: Record<string, number> = {};

//     for (const [stratAddress, metadata] of Object.entries(await response.json()) as any) {
//       const strat = await hre.ethers.getContractAt('IYakStrategy', stratAddress);
//       try {
//         const token: string = getAddress(await strat.depositToken());

//         const extantStrat = token2strategy[token];
//         if (!extantStrat || metadata.lastReinvest.timestamp > strategy2timestamp[extantStrat]) {
//           token2strategy[token] = stratAddress;
//         }

//         strategy2timestamp[stratAddress] = metadata.lastReinvest.timestamp;
//       } catch (e) {
//         console.error(e);
//       }
//     }
//     await fs.promises.writeFile(
//       yyStratPath,
//       JSON.stringify(
//         {
//           token2strategy,
//           strategy2timestamp
//         },
//         null,
//         2
//       )
//     );

//     return {
//       token2strategy,
//       strategy2timestamp
//     };
//   }
// }
