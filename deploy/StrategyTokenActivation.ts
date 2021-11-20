import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { LPTokensByAMM, tokensPerNetwork } from './TokenActivation';
import path from 'path';
import * as fs from 'fs';
import fetch from 'node-fetch';
import { BigNumber } from '@ethersproject/bignumber';
import { getAddress } from '@ethersproject/address';
import { parseEther } from '@ethersproject/units';
import IERC20 from '@openzeppelin/contracts/build/contracts/IERC20.json';

const SimpleHoldingStrategy = { strategy: 'SimpleHoldingStrategy', args: [500], depositLimit: parseEther('100') };
const TraderJoeMasterChefStrategy = 'TraderJoeMasterChefStrategy';
const PangolinStakingRewardsStrategy = 'PangolinStakingRewardsStrategy';

type StrategyConfig = {
  strategy: string;
  args: any[];
  depositLimit: BigNumber;
};

const strategiesPerNetwork: Record<string, Record<string, StrategyConfig[]>> = {
  hardhat: {
    USDCe: [],
    WETHe: [],
    WAVAX: [],
    USDTe: [SimpleHoldingStrategy],
    PNG: [],
    JOE: [SimpleHoldingStrategy]
  },
  avalanche: {
    USDCe: [],
    WETHe: [],
    WAVAX: [],
    USDTe: [],
    PNG: [],
    JOE: [SimpleHoldingStrategy]
  }
};

const lptStrategies: Record<string, Record<string, string>> = {
  hardhat: {
    traderJoe: TraderJoeMasterChefStrategy,
    pangolin: PangolinStakingRewardsStrategy
  },
  avalanche: {
    traderJoe: TraderJoeMasterChefStrategy,
    pangolin: PangolinStakingRewardsStrategy
  }
};

// TODO: choice of strategies, tokens and deposit limits must be done by hand

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  await augmentStrategiesPerNetworkWithLPT(hre);
  await augmentStrategiesPerNetworkWithYY(hre);

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

  const args: [string[], string[], BigNumber[], string[], string] = [[], [], [], [], roles.address];
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
        args[2].push(strategy.depositLimit);
        args[3].push(tokenData);

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

  for (const [amm, strategyName] of Object.entries(lptStrategies[networkName])) {
    const lpRecords = lpTokensByAMM[chainId][amm];

    for (const [jointTicker, lpRecord] of Object.entries(lpRecords)) {
      if (lpRecord.pid) {
        const depositLimit = (
          await (await hre.ethers.getContractAt(IERC20.abi, lpRecord.pairAddress)).totalSupply()
        ).div(10);
        tokenStrategies[jointTicker] = [{ strategy: strategyName, args: [lpRecord.pid], depositLimit }];
        tokensPerNetwork[networkName][jointTicker] = lpRecord.pairAddress!;
      } else if (lpRecord.stakingContract) {
        const depositLimit = (
          await (await hre.ethers.getContractAt(IERC20.abi, lpRecord.pairAddress)).totalSupply()
        ).div(10);
        tokenStrategies[jointTicker] = [{ strategy: strategyName, args: [lpRecord.stakingContract], depositLimit }];
        tokensPerNetwork[networkName][jointTicker] = lpRecord.pairAddress!;
      }
    }
  }
}

async function augmentStrategiesPerNetworkWithYY(hre: HardhatRuntimeEnvironment) {
  const tokenStrategies = strategiesPerNetwork[hre.network.name];
  console.log(`network name: ${hre.network.name}`);
  if (['avalanche', 'localhost', 'hardhat', 'local'].includes(hre.network.name)) {
    const { token2strategy } = await getYYStrategies(hre);
    for (const [tokenName, tokenAddress] of Object.entries(tokensPerNetwork[hre.network.name])) {
      const stratAddress = token2strategy[tokenAddress];
      if (stratAddress) {
        const depositLimit = (await (await hre.ethers.getContractAt(IERC20.abi, stratAddress)).totalSupply()).div(10);
        tokenStrategies[tokenName] = [
          { strategy: 'YieldYakStrategy', args: [stratAddress], depositLimit },
          ...(tokenStrategies[tokenName] ?? [])
        ];
      }
    }
  }
}

const yyAPI = 'https://staging-api-dot-avalanche-304119.ew.r.appspot.com/apys';
async function getYYStrategies(hre: HardhatRuntimeEnvironment) {
  console.log(`Getting yy strategy data`);
  const yyStratPath = path.join(__dirname, '../build/yy-strategies.json');
  if (fs.existsSync(yyStratPath)) {
    console.log(`Reading YY strategies from ${yyStratPath}`);
    return JSON.parse((await fs.promises.readFile(yyStratPath)).toString());
  } else {
    console.log(`Fetching YY strategies from API`);
    const response = await fetch(yyAPI);

    const token2strategy: Record<string, string> = {};
    const strategy2timestamp: Record<string, number> = {};

    for (const [stratAddress, metadata] of Object.entries(await response.json()) as any) {
      const strat = await hre.ethers.getContractAt('IYakStrategy', stratAddress);
      try {
        const token: string = getAddress(await strat.depositToken());

        const extantStrat = token2strategy[token];
        if (!extantStrat || metadata.lastReinvest.timestamp > strategy2timestamp[extantStrat]) {
          token2strategy[token] = stratAddress;
        }

        strategy2timestamp[stratAddress] = metadata.lastReinvest.timestamp;
      } catch (e) {
        console.error(e);
      }
    }
    await fs.promises.writeFile(
      yyStratPath,
      JSON.stringify(
        {
          token2strategy,
          strategy2timestamp
        },
        null,
        2
      )
    );

    return {
      token2strategy,
      strategy2timestamp
    };
  }
}
