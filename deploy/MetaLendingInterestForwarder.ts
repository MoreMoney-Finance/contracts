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
  const IMoney = await deployments.get('iMoney');
  const imoney = await ethers.getContractAt('iMoney', IMoney.address);
  console.log('[imoney.address, roles.address]', [imoney.address, roles.address]);
  const MetaLendingInterestForwarder = await deploy('MetaLendingInterestForwarder', {
    from: deployer,
    args: [imoney.address, roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, MetaLendingInterestForwarder.address, 'MetaLendingInterestForwarder');
};
deploy.tags = ["MetaLendingInterestForwarder", "base"];
deploy.dependencies = ["Roles", 'iMoney', 'MetaLending'];
export default deploy;
