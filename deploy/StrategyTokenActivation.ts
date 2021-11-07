import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { LPTokensByAMM, tokensPerNetwork } from './TokenActivation';
import path from 'path';
import * as fs from 'fs';

const SimpleHoldingStrategy = { strategy: 'SimpleHoldingStrategy', args: [500] };
const TraderJoeMasterChefStrategy = 'TraderJoeMasterChefStrategy';
const PangolinStakingRewardsStrategy = 'PangolinStakingRewardsStrategy';

type StrategyConfig = {
  strategy: string;
  args: any[];
};

const strategiesPerNetwork: Record<string, Record<string, StrategyConfig[]>> = {
  hardhat: {
    USDCe: [SimpleHoldingStrategy],
    WETHe: [SimpleHoldingStrategy],
    WAVAX: [SimpleHoldingStrategy],
    USDTe: [SimpleHoldingStrategy],
    PNG: [SimpleHoldingStrategy],
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

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network,
  ethers
}: HardhatRuntimeEnvironment) {
  await augmentStrategiesPerNetworkWithLPT(network.name, await getChainId());
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const tokenAddresses = tokensPerNetwork[network.name];
  const tokenStrategies = strategiesPerNetwork[network.name];

  const args: [string[], string[], string[], string] = [[], [], [], roles.address];
  for (const [tokenName, strategies] of Object.entries(tokenStrategies)) {
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

    const dC = await ethers.getContractAt(
      'DependencyController',
      (
        await deployments.get('DependencyController')
      ).address
    );

    const tx = await dC.executeAsOwner(StrategyTokenActivation.address);
    console.log(`Executing strategy token activation as owner: ${tx.hash}`);
  }
};

deploy.tags = ['StrategyTokenActivation', 'base'];
deploy.dependencies = [
  'TokenActivation',
  'DependencyController',
  'SimpleHoldingStrategy',
  'TraderJoeMasterChefStrategy',
  'PangolinStakingRewardsStrategy'
];
deploy.runAtTheEnd = true;
export default deploy;

// For MasterChef:
// per each masterchef pull all the PIDs and cache in a JSON file
// go through all the pairs generated per DEX
// look up their addresses in that PID cache
// activate if necessary

async function augmentStrategiesPerNetworkWithLPT(networkName: string, chainId: string) {
  const tokenStrategies = strategiesPerNetwork[networkName];

  const lpTokensPath = path.join(__dirname, '../build/lptokens.json');
  const lpTokensByAMM: LPTokensByAMM = JSON.parse((await fs.promises.readFile(lpTokensPath)).toString());

  for (const [amm, strategyName] of Object.entries(lptStrategies[networkName])) {
    const lpRecords = lpTokensByAMM[chainId][amm];

    for (const [jointTicker, lpRecord] of Object.entries(lpRecords)) {
      if (lpRecord.pid) {
        tokenStrategies[jointTicker] = [{ strategy: strategyName, args: [lpRecord.pid] }];
        tokensPerNetwork[networkName][jointTicker] = lpRecord.pairAddress!;
      } else if (lpRecord.stakingContract) {
        tokenStrategies[jointTicker] = [{ strategy: strategyName, args: [lpRecord.stakingContract] }];
        tokensPerNetwork[networkName][jointTicker] = lpRecord.pairAddress!;
      }
    }
  }
}
