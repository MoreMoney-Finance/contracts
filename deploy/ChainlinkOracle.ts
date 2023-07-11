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
  const networkName = process.env.NETWORK_NAME;

  const usdt = tokensPerNetwork[networkName].USDT;
  
  const ChainlinkOracle = await deploy('ChainlinkOracle', {
    from: deployer,
    args: [usdt, tokenInitRecords[networkName].USDT.decimals, roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, ChainlinkOracle.address, 'ChainlinkOracle');
};
deploy.tags = ['ChainlinkOracle', 'base'];
deploy.dependencies = ['DependencyController'];
export default deploy;
