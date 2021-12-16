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
  const { deployer } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const OracleRegistry = await deploy('OracleRegistry', {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, OracleRegistry.address, 'OracleRegistry');
};
deploy.tags = ['OracleRegistry', 'base'];
deploy.dependencies = ['DependencyController'];
export default deploy;
