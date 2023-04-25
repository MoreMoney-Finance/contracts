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

  const DeltaPrimeStrategy = await deploy('DeltaPrimeStrategy', {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, DeltaPrimeStrategy.address, 'DeltaPrimeStrategy');
  await registerStrategy(deployments, DeltaPrimeStrategy.address);
};
deploy.tags = ['DeltaPrimeStrategy', 'avalanche'];
deploy.dependencies = ['DependencyController', 'TrancheIDService', 'StrategyRegistry'];
deploy.skip = async (hre: HardhatRuntimeEnvironment) => !new Set(['31337', '43114']).has(await hre.getChainId());
deploy.runAtTheEnd = true;
export default deploy;
