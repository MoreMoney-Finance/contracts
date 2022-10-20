import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
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

  const MetaLendingLiquidation = await deploy("MetaLendingLiquidation", {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  await manage(
    deployments,
    MetaLendingLiquidation.address,
    "MetaLendingLiquidation"
  );
};
deploy.tags = ["MetaLendingLiquidation", "base"];
deploy.dependencies = ["DependencyController"];
export default deploy;
