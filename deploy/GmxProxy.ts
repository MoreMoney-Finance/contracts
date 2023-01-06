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
  const gmxDepositor = await deployments.get('GmxDepositor');
  
  const GmxProxy = await deploy('GmxProxy', {
    from: deployer,
    args: [
      gmxDepositor.address,
      "0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1",
      deployer
    ],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, GmxProxy.address, 'GmxProxy');
};
deploy.tags = ['GmxProxy', 'base'];
deploy.dependencies = ['DependencyController', 'GmxDepositor'];
export default deploy;