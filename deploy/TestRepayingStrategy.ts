import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './DependencyController';
import { registerStrategy } from './StrategyRegistry';
import { tokensPerNetwork } from './TokenActivation';

import IERC20 from '@openzeppelin/contracts/build/contracts/IERC20.json';
import { parseEther } from '@ethersproject/units';
const { ethers } = require('hardhat');

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const usdt = tokensPerNetwork.hardhat.USDTe;

  const TestRepayingStrategy = await deploy('TestRepayingStrategy', {
    from: deployer,
    args: [usdt, roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, TestRepayingStrategy.address, 'TestRepayingStrategy');
  await registerStrategy(deployments, TestRepayingStrategy.address);

  const usdtContract = await ethers.getContractAt(IERC20.abi, usdt);
  await usdtContract.approve(TestRepayingStrategy.address, parseEther('999999999999999999999'));
};
deploy.tags = ['TestRepayingStrategy'];
deploy.dependencies = ['DependencyController', 'TrancheIDService', 'StrategyRegistry'];
deploy.skip = async (hre: HardhatRuntimeEnvironment) => !new Set(['31337']).has(await hre.getChainId());
export default deploy;
