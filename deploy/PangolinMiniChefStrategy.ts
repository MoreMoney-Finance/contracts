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

  const PangolinMiniChefStrategy = await deploy('PangolinMiniChefStrategy', {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, PangolinMiniChefStrategy.address);
  registerStrategy(deployments, PangolinMiniChefStrategy.address);
};
deploy.tags = ['PangolinMiniChefStrategy', 'avalanche'];
deploy.dependencies = ['DependencyController', 'TrancheIDService', 'StrategyRegistry'];
deploy.skip = async (hre: HardhatRuntimeEnvironment) => !new Set(['31337', '43114']).has(await hre.getChainId());
export default deploy;
