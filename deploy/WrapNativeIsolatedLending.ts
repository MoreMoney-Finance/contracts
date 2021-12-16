import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './DependencyController';
const { ethers } = require('hardhat');

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, baseCurrency } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const WrapNativeIsolatedLending = await deploy('WrapNativeIsolatedLending', {
    from: deployer,
    args: [baseCurrency, roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, WrapNativeIsolatedLending.address, 'WrapNativeIsolatedLending');
};
deploy.tags = ['WrapNativeIsolatedLending', 'base'];
deploy.dependencies = ['DependencyController'];
export default deploy;
