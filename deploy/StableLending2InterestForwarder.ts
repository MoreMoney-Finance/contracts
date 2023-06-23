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
  /*
  const StableLending2InterestForwarder = await deploy('StableLending2InterestForwarder', {
    from: deployer,
    args: [imoney.address, roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, StableLending2InterestForwarder.address, 'StableLending2InterestForwarder');
  */
};
deploy.tags = ["StableLending2InterestForwarder", "base"];
deploy.dependencies = ["Roles", 'iMoney', 'StableLending2'];
export default deploy;
