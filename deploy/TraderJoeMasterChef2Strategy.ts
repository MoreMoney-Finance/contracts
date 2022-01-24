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

  const TraderJoeMasterChef2Strategy = await deploy('TraderJoeMasterChef2Strategy', {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, TraderJoeMasterChef2Strategy.address, 'TraderJoeMasterChef2Strategy');
  await registerStrategy(deployments, TraderJoeMasterChef2Strategy.address);
};
deploy.tags = ['TraderJoeMasterChef2Strategy', 'avalanche'];
deploy.dependencies = ['DependencyController', 'TrancheIDService', 'StrategyRegistry'];
deploy.skip = async (hre: HardhatRuntimeEnvironment) => !new Set(['31337', '43114']).has(await hre.getChainId());
export default deploy;
