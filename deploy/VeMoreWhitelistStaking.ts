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
  const more = await deployments.get('MoreToken');
  const vemore = await deployments.get('VeMoreToken');
  const VeMoreWhitelistStaking = await deploy('VeMoreWhitelistStaking', {
    from: deployer,
    args: [more.address, vemore.address, roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, VeMoreWhitelistStaking.address, 'VeMoreWhitelistStaking');
};
deploy.tags = ['VeMoreWhitelistStaking', 'base'];
deploy.dependencies = ['DependencyController', 'VeMoreToken', 'MoreToken'];
export default deploy;
