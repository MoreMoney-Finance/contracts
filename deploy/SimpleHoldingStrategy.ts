import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './DependencyController';
import { registerStrategy } from './StrategyRegistry';
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

  const SimpleHoldingStrategy = await deploy('SimpleHoldingStrategy', {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, SimpleHoldingStrategy.address);
  await registerStrategy(deployments, SimpleHoldingStrategy.address);
};
deploy.tags = ['SimpleHoldingStrategy', 'base'];
deploy.dependencies = ['DependencyController', 'TrancheIDService', 'StrategyRegistry'];
export default deploy;
