import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './ContractManagement';
import { registerStrategy } from './ContractManagement';
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

  const YieldYakAVAXStrategy2v2 = await deploy('YieldYakAVAXStrategy2v2', {
    from: deployer,
    args: [baseCurrency, roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, YieldYakAVAXStrategy2v2.address, 'YieldYakAVAXStrategy2v2');
  await registerStrategy(deployments, YieldYakAVAXStrategy2v2.address);
  
};
deploy.tags = ['YieldYakAVAXStrategy2v2', 'avalanche'];
deploy.dependencies = ['DependencyController', 'TrancheIDService', 'StrategyRegistry'];
deploy.skip = async (hre: HardhatRuntimeEnvironment) => !new Set(['31337', '43114']).has(await hre.getChainId());
export default deploy;
