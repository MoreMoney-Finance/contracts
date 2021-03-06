import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers, getChainId } from 'hardhat';
import { DeploymentsExtension } from 'hardhat-deploy/dist/types';

export type ManagedContract = {
  contractName: string;
  charactersPlayed: number[];
  rolesPlayed: number[];
};

export const MINTER_BURNER = 2;

export const PROTOCOL_TOKEN = 100;
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

  // if ((await roles.mainCharacters(DISABLER)) != deployer) {
  //   const tx = await roles.setMainCharacter(DISABLER, deployer);
  //   console.log(`Giving disabler main character: ${tx.hash}`);
  //   await tx.wait();
  // }

  if (network.name === 'hardhat') {
    await assignMainCharacter(deployments, deployer, FEE_RECIPIENT, 'fee recipient');
  }
};

deploy.tags = ['DependencyController', 'base'];
deploy.dependencies = ['Roles'];
export default deploy;

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
