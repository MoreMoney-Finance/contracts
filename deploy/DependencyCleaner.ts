import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
import { BigNumber } from 'ethers';

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy, all } = deployments;
  const { deployer } = await getNamedAccounts();

  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const DependencyController = await deployments.get('DependencyController');
  const dc = await ethers.getContractAt('DependencyController', DependencyController.address);

  // TODO: load from somewhere
  const contractAddresses = {};

  const currentAddresses = new Set(Object.values(await all()).map(depl => depl.address));
  // just in case include
  Object.values(contractAddresses[await getChainId()]).forEach((a: string) => currentAddresses.add(a));

  const managedContracts: string[] = [];

  for (let i = 0; 1000 > i; i++) {
    try {
      managedContracts.push(await dc.managedContracts(i));
    } catch (e) {
      break;
    }
  }

  console.log(managedContracts);
  console.log(currentAddresses);

  const knownRoles: BigNumber[] = [];
  for (let i = 0; 1000 > i; i++) {
    try {
      knownRoles.push(await dc.allRoles(i));
    } catch (e) {
      break;
    }
  }
  console.log(knownRoles);

  const excessContracts = managedContracts.filter(address => !currentAddresses.has(address));
  console.log('excess contracts:');
  console.log(excessContracts);

  const trashContracts = [];
  const trashRoles = [];

  for (const contract of excessContracts) {
    for (const kr of knownRoles) {
      if (await roles.getRole(kr, contract)) {
        trashContracts.push(contract);
        trashRoles.push(kr);
      }
    }
  }

  console.log('DependencyCleaner args:');
  console.log(trashContracts);
  console.log(trashRoles);

  if (trashContracts.length > 0) {
    const Job = await deploy('DependencyCleaner', {
      from: deployer,
      args: [trashContracts, trashRoles, Roles.address],
      log: true,
      skipIfAlreadyDeployed: true
    });

    // run if it hasn't self-destructed yet
    if ((await ethers.provider.getCode(Job.address)) !== '0x') {
      console.log(`Executing dependency cleaner ${Job.address} via dependency controller ${dc.address}`);
      const tx = await dc.executeAsOwner(Job.address, { gasLimit: 8000000 });
      console.log(`ran ${Job.address} as owner, tx: ${tx.hash} with gasLimit: ${tx.gasLimit}`);
    }
  }
};
deploy.tags = ['DependencyCleaner', 'local'];
deploy.dependencies = ['Roles', 'DependencyController'];
deploy.runAtTheEnd = true;
export default deploy;
