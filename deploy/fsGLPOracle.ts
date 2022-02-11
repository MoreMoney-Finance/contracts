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

  const fsGLPOracle = await deploy('fsGLPOracle', {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, fsGLPOracle.address, 'fsGLPOracle');
};
deploy.tags = ['fsGLPOracle', 'base'];
deploy.dependencies = ['DependencyController'];
export default deploy;
