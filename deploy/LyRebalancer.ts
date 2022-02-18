import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './ContractManagement';
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

  const LyRebalancer = await deploy('LyRebalancer', {
    from: deployer,
    args: [
        (await deployments.get('msAvax')).address,
        (await deployments.get('mAvax')).address,
        (await deployments.get('LyLptHolder')).address,
        roles.address
    ],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, LyRebalancer.address, 'LyRebalancer');
};
deploy.tags = ['LyRebalancer', 'base'];
deploy.dependencies = ['DependencyController', 'msAvax', 'mAvax', 'LyLptHolder'];
export default deploy;
