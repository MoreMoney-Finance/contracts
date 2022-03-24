import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './ContractManagement';
import { registerStrategy } from './ContractManagement';
import { net } from './Roles';
import { tokensPerNetwork } from './TokenActivation';
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

  const netname = net(network.name);
  const yak = tokensPerNetwork[netname].YAK;
  const wavax = tokensPerNetwork[netname].WAVAX;

  const YakSelfRepayingStrategy = await deploy('YakSelfRepayingStrategy', {
    from: deployer,
    args: [yak, baseCurrency, [wavax], roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, YakSelfRepayingStrategy.address, 'YakSelfRepayingStrategy');
  await registerStrategy(deployments, YakSelfRepayingStrategy.address);
};
deploy.tags = ['YakSelfRepayingStrategy', 'avalanche'];
deploy.dependencies = ['DependencyController', 'TrancheIDService', 'StrategyRegistry', 'msAvax', 'mAvax'];
deploy.skip = async (hre: HardhatRuntimeEnvironment) => !new Set(['31337', '43114']).has(await hre.getChainId());
export default deploy;
