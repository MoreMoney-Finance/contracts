import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './DependencyController';
import { tokenInitRecords, tokensPerNetwork } from './TokenActivation';
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

  const usdc = tokensPerNetwork[network.name].USDC;

  const ChainlinkOracle = await deploy('ChainlinkOracle', {
    from: deployer,
    args: [usdc, tokenInitRecords.USDC.decimals, roles.address],
    log: true,
    skipIfAlreadyDeployed: true,
    deterministicDeployment: true
  });

  await manage(deployments, ChainlinkOracle.address);
};
deploy.tags = ['ChainlinkOracle', 'base'];
deploy.dependencies = ['DependencyController'];
export default deploy;