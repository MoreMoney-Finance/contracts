import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './ContractManagement';
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
  const tokens = [
    '0xE5e9d67e93aD363a50cABCB9E931279251bBEFd0',
    '0x9e295B5B976a184B14aD8cd72413aD846C299660',
    '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
    '0x152b9d0FdC40C096757F570A51E494bd4b943E50',
    '0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE',
    '0xF7D9281e8e363584973F946201b82ba72C965D27'
  ]

  const BufferActivation = await deploy('BufferActivation', {
    from: deployer,
    args: [tokens, roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, BufferActivation.address, 'BufferActivation');
};
deploy.tags = ['BufferActivation', 'base'];
deploy.dependencies = ['DependencyController', 'TokenActivation'];
deploy.runAtTheEnd = true;
export default deploy;
