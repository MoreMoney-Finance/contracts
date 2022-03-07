import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './ContractManagement';
import { BigNumber } from 'ethers';
import { parseEther } from '@ethersproject/units';
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

  const StableLending = await deploy('StableLending', {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, StableLending.address, 'StableLending');

  if (network.name === 'hardhat') {
    const trancheIDService = await ethers.getContractAt(
      'TrancheIDService',
      (
        await deployments.get('TrancheIDService')
      ).address
    );
    if (!(await trancheIDService.viewSlotByTrancheContract(StableLending.address)).gt(0)) {
      const tx = await (await ethers.getContractAt('IsolatedLending', StableLending.address)).setupTrancheSlot();
      console.log(`Setting up tranche slot for isolated lending: ${tx.hash}`);
      await tx.wait();
    }
  }
};
deploy.tags = ['StableLending', 'base'];
deploy.dependencies = ['DependencyController', 'TrancheIDService'];
export default deploy;
