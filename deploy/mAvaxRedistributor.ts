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

  const mAvaxRedistributor = await deploy('mAvaxRedistributor', {
    from: deployer,
    args: [
        (await deployments.get('mAvax')).address,
        [joe, qi], // png
        roles.address
    ],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, mAvaxRedistributor.address, 'mAvaxRedistributor');
};
deploy.tags = ['mAvaxRedistributor', 'base'];
deploy.dependencies = ['DependencyController'];
export default deploy;
