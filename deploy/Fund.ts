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

  const Fund = await deploy('Fund', {
    from: deployer,
    args: [baseCurrency, roles.address],
    log: true,
    skipIfAlreadyDeployed: true,
    deterministicDeployment: true
  });

  await manage(deployments, Fund.address);
};
deploy.tags = ['Fund', 'base'];
deploy.dependencies = ['DependencyController'];
export default deploy;
