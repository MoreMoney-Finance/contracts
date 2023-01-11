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
  // const { deploy } = deployments;
  // const { deployer, baseCurrency } = await getNamedAccounts();
  // const Roles = await deployments.get('Roles');
  // const roles = await ethers.getContractAt('Roles', Roles.address);


  // const netname = net(network.name);
  // const xJoe = tokensPerNetwork[netname].xJOE;
  // const joe = tokensPerNetwork[netname].JOE;
  // const usdc = tokensPerNetwork[netname].USDCe;

  // const sJoeStrategy = await deploy('sJoeStrategy', {
  //   from: deployer,
  //   args: [
  //       xJoe,
  //       joe,
  //       baseCurrency,
  //       [usdc],
  //       roles.address
  //   ],
  //   log: true,
  //   skipIfAlreadyDeployed: true
  // });

  // await manage(deployments, sJoeStrategy.address, 'sJoeStrategy');
  // await registerStrategy(deployments, sJoeStrategy.address);
};
deploy.tags = ['sJoeStrategy', 'avalanche'];
deploy.dependencies = ['DependencyController', 'TrancheIDService', 'StrategyRegistry', 'msAvax', 'mAvax'];
deploy.skip = async (hre: HardhatRuntimeEnvironment) => !new Set(['31337', '43114']).has(await hre.getChainId());
export default deploy;
