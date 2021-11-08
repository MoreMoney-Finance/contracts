import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './DependencyController';
import { DeploymentsExtension } from 'hardhat-deploy/dist/types';
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

  const StrategyRegistry = await deploy('StrategyRegistry', {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, StrategyRegistry.address);
};
deploy.tags = ['StrategyRegistry', 'base'];
deploy.dependencies = ['DependencyController'];
export default deploy;

export async function registerStrategy(deployments: DeploymentsExtension, strategyAddress: string): Promise<void> {
  const registry = await ethers.getContractAt('StrategyRegistry', (await deployments.get('StrategyRegistry')).address);
  if (!(await registry.enabledStrategy(strategyAddress))) {
    const tx = await registry.enableStrategy(strategyAddress);
    console.log(`Enabling strategy at ${strategyAddress} with tx: ${tx.hash}`);
    await tx.wait();
  }
}
