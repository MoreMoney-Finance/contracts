import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { DeploymentsExtension } from "hardhat-deploy/dist/types";

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
const FEE_CONTROLLER = 105;
const PRICE_CONTROLLER = 106;
const ADMIN = 107;

const DISABLER = 1001;
const DEPENDENCY_CONTROLLER = 1002;

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
    network,
  } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const Roles = await deployments.get("Roles");

  const DependencyController = await deploy("DependencyController", {
    from: deployer,
    args: [Roles.address],
    log: true,
    skipIfAlreadyDeployed: true,
    deterministicDeployment: true,
  });

  const roles = await ethers.getContractAt("Roles", Roles.address);

  if (
    (await roles.mainCharacters(DEPENDENCY_CONTROLLER)) !=
    DependencyController.address
  ) {
    const givingRole = await roles.setMainCharacter(
      DEPENDENCY_CONTROLLER,
      DependencyController.address,
      {
        gasLimit: 8000000,
      }
    );
    console.log(`Giving dependency controller role: ${givingRole.hash}`);
  }

  if ((await roles.mainCharacters(DISABLER)) != deployer) {
    const tx = await roles.giveRole(DISABLER, deployer);
    console.log(`Giving disabler role: ${tx.hash}`);
  }
};

deploy.tags = ["DependencyController", "base"];
deploy.dependencies = ["Roles"];
export default deploy;

export async function manage(
  deployments: DeploymentsExtension,
  contractAddress: string
): Promise<void> {
  const dC = await ethers.getContractAt(
    "DependencyController",
    (
      await deployments.get("DependencyController")
    ).address
  );

  const alreadyManaged = await dC.allManagedContracts();
  if (!alreadyManaged.includes(contractAddress)) {
    const tx = await dC.manageContract(contractAddress, { gasLimit: 8000000 });
    console.log(
      `dependencyController.manageContract(${contractAddress}, ...) tx: ${tx.hash}`
    );
  }
}
