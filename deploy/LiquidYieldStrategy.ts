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

  const LiquidYieldStrategy = await deploy('LiquidYieldStrategy', {
    from: deployer,
    args: [
        (await deployments.get('msAvax')).address,
        (await deployments.get('mAvax')).address,
        baseCurrency,
        roles.address
    ],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, LiquidYieldStrategy.address, 'LiquidYieldStrategy');
  await registerStrategy(deployments, LiquidYieldStrategy.address);
};
deploy.tags = ['LiquidYieldStrategy', 'avalanche'];
deploy.dependencies = ['DependencyController', 'TrancheIDService', 'StrategyRegistry', 'msAvax', 'mAvax'];
deploy.skip = async (hre: HardhatRuntimeEnvironment) => !new Set(['31337', '43114']).has(await hre.getChainId());
export default deploy;
