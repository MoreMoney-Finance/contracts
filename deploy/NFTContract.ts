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

  // get contract MetaLending
  const MetaLending = await ethers.getContractAt(
    "MetaLending",
    (
      await deployments.get("MetaLending")
    ).address
  );

  const NFTContract = await deploy("NFTContract", {
    from: deployer,
    args: [roles.address, MetaLending.address],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  await manage(deployments, NFTContract.address, "NFTContract");
};
deploy.tags = ["NFTContract", "base"];
deploy.dependencies = ["DependencyController", "TrancheIDService", "InterestRateController", "MetaLending"];
// deploy.runAtTheEnd = true;
export default deploy;
