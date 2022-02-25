import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './ContractManagement';
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
  const { deployer } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const netname = net(network.name);
  const joe = tokensPerNetwork[netname].JOE;
  const qi = tokensPerNetwork[netname].QI;

  const LyLptHolder = await deploy('LyLptHolder', {
    from: deployer,
    args: [
        [joe, qi],
        [
            (await deployments.get('msAvaxRedistributor')).address,
            (await deployments.get('mAvaxRedistributor')).address,
            deployer
        ],
        [45, 50, 5],
        roles.address
    ],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, LyLptHolder.address, 'LyLptHolder');
};
deploy.tags = ['LyLptHolder', 'base'];
deploy.dependencies = ['DependencyController', 'mAvaxRedistributor', 'msAvaxRedistributor'];
export default deploy;
