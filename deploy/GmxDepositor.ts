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

  const GmxDepositor = await deploy('GmxDepositor', {
    from: deployer,
    args: [],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, GmxDepositor.address, 'GmxDepositor');
};
deploy.tags = ['GmxDepositor', 'base'];
deploy.dependencies = ['DependencyController'];
deploy.runAtTheEnd = true;
export default deploy;