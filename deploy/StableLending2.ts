import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { manage } from "./ContractManagement";
import { BigNumber } from "ethers";
import { parseEther } from "@ethersproject/units";
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

  const StableLending2 = await deploy("StableLending2", {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  await manage(deployments, StableLending2.address, "StableLending2");

  if (network.name === "hardhat") {
    const trancheIDService = await ethers.getContractAt(
      "TrancheIDService",
      (
        await deployments.get("TrancheIDService")
      ).address
    );
    if (
      !(
        await trancheIDService.viewSlotByTrancheContract(StableLending2.address)
      ).gt(0)
    ) {
      const tx = await (
        await ethers.getContractAt("IsolatedLending", StableLending2.address)
      ).setupTrancheSlot();
      console.log(`Setting up tranche slot for isolated lending: ${tx.hash}`);
      await tx.wait();
    }
  }
};
deploy.tags = ["StableLending2", "base"];
deploy.dependencies = ["DependencyController", "TrancheIDService", "InterestRateController"];
export default deploy;
