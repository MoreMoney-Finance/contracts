import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers, getChainId } from 'hardhat';
import { DeploymentsExtension } from 'hardhat-deploy/dist/types';
import * as addresses from '../build/addresses.json';

export type ManagedContract = {
  contractName: string;
  charactersPlayed: number[];
  rolesPlayed: number[];
};

const WITHDRAWER = 1;
const BORROWER = 3;
const INCENTIVE_REPORTER = 8;
const STAKE_PENALIZER = 10;

const FUND = 101;
const LENDING = 102;
const FEE_RECIPIENT = 103;
export const CURVE_POOL = 109;

const DISABLER = 1001;
const DEPENDENCY_CONTROLLER = 1002;

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { getNamedAccounts, deployments, getChainId, getUnnamedAccounts, network } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');

  const DependencyController = await deploy('DependencyController', {
    from: deployer,
    args: [Roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  const roles = await ethers.getContractAt('Roles', Roles.address);

  if ((await roles.mainCharacters(DEPENDENCY_CONTROLLER)) != DependencyController.address) {
    const givingRole = await roles.setMainCharacter(DEPENDENCY_CONTROLLER, DependencyController.address, {
      gasLimit: 8000000
    });
    console.log(`Giving dependency controller main character: ${givingRole.hash}`);
    await givingRole.wait();
  }

  if ((await roles.mainCharacters(DISABLER)) != deployer) {
    const tx = await roles.setMainCharacter(DISABLER, deployer);
    console.log(`Giving disabler main character: ${tx.hash}`);
    await tx.wait();
  }

  await assignMainCharacter(deployments, deployer, FEE_RECIPIENT, 'fee recipient');
};

deploy.tags = ['DependencyController', 'base'];
deploy.dependencies = ['Roles'];
export default deploy;

export async function manage(deployments: DeploymentsExtension, contractAddress: string, contractName): Promise<void> {
  const dC = await ethers.getContractAt(
    'DependencyController',
    (
      await deployments.get('DependencyController')
    ).address
  );

  const alreadyManaged = (await dC.allManagedContracts()).map(a => a.toLowerCase());
  if (!alreadyManaged.includes(contractAddress.toLowerCase())) {
    const chainId = await getChainId();
    const chainAddresses = addresses[chainId];
    if (
      chainId !== '31337' &&
      contractName in chainAddresses &&
      alreadyManaged.includes(chainAddresses[contractName].toLowerCase())
    ) {
      const tx = await dC.replaceContract(chainAddresses[contractName], contractAddress, { gasLimit: 8000000 });
      console.log(
        `dependencyController.replaceContract(${contractName} replacing ${chainAddresses[contractName]} for ${contractAddress}) tx: ${tx.hash}`
      );

      await tx.wait();
    } else {
      const tx = await dC.manageContract(contractAddress, { gasLimit: 8000000 });
      console.log(`dependencyController.manageContract(${contractName} at ${contractAddress}) tx: ${tx.hash}`);

      await tx.wait();
    }
  }
}

export async function assignMainCharacter(
  deployments: DeploymentsExtension,
  characterAddress: string,
  characterId: number,
  characterName: string
) {
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);
  const DependencyController = await deployments.get('DependencyController');
  const dC = await ethers.getContractAt('DependencyController', DependencyController.address);

  if ((await roles.mainCharacters(characterId)).toLowerCase() !== characterAddress.toLowerCase()) {
    const givingRole = await dC.setMainCharacter(characterId, characterAddress, {
      gasLimit: 8000000
    });
    console.log(`Giving ${characterName} character: ${givingRole.hash}`);
    await givingRole.wait();
  }
}
