import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { manage } from "./DependencyController";
import { BigNumber } from "ethers";
const { ethers } = require("hardhat");

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const Roles = await deployments.get("Roles");
  const roles = await ethers.getContractAt("Roles", Roles.address);

  const IsolatedLending = await deploy("IsolatedLending", {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true,
    deterministicDeployment: true,
  });

  await manage(deployments, IsolatedLending.address);

  const trancheIDService = await ethers.getContractAt(
    "TrancheIDService",
    (
      await deployments.get("TrancheIDService")
    ).address
  );
  if (
    !(
      await trancheIDService.viewSlotByTrancheContract(IsolatedLending.address)
    ).gt(0)
  ) {
    const tx = await (
      await ethers.getContractAt("IsolatedLending", IsolatedLending.address)
    ).setupTrancheSlot();
    console.log(`Setting up tranche slot for isolated lending: ${tx.hash}`);
  }
};
deploy.tags = ["IsolatedLending", "base"];
deploy.dependencies = ["DependencyController", "TrancheIDService"];
export default deploy;
