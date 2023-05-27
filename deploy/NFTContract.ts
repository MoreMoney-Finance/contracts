import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { manage } from "./ContractManagement";
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

  // get contract StableLending2 
  const StableLending2 = await ethers.getContractAt(
    "StableLending2",
    (
      await deployments.get("StableLending2")
    ).address
  );

  const NFTContract = await deploy("NFTContract", {
    from: deployer,
    args: [roles.address, StableLending2.address],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  await manage(deployments, NFTContract.address, "NFTContract");
};
deploy.tags = ["NFTContract", "base"];
deploy.dependencies = ["DependencyController", "TrancheIDService", "InterestRateController", "StableLending2"];
// deploy.runAtTheEnd = true;
export default deploy;
