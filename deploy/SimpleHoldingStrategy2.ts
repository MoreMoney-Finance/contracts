import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './ContractManagement';
import { registerStrategy } from './ContractManagement';
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

  const SimpleHoldingStrategy2 = await deploy('SimpleHoldingStrategy2', {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, SimpleHoldingStrategy2.address, 'SimpleHoldingStrategy2');
  await registerStrategy(deployments, SimpleHoldingStrategy2.address);
};
deploy.tags = ['SimpleHoldingStrategy2', 'base'];
deploy.dependencies = ['DependencyController', 'TrancheIDService', 'StrategyRegistry'];
export default deploy;
