import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './ContractManagement';
import { tokenInitRecords, tokensPerNetwork } from './TokenActivation';
import { net } from './Roles';
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

  const ChainlinkNonStaleOracle = await deploy('ChainlinkNonStaleOracle', {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, ChainlinkNonStaleOracle.address, 'ChainlinkNonStaleOracle');
};
deploy.tags = ['ChainlinkNonStaleOracle', 'base'];
deploy.dependencies = ['DependencyController'];
export default deploy;
