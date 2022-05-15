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
  const { deployer, baseCurrency } = await getNamedAccounts();
  const Roles = await deployments.get("Roles");
  const roles = await ethers.getContractAt("Roles", Roles.address);

  const WrapNativeStableLending2 = await deploy("WrapNativeStableLending2", {
    from: deployer,
    args: [baseCurrency, roles.address],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  await manage(
    deployments,
    WrapNativeStableLending2.address,
    "WrapNativeStableLending2"
  );
};
deploy.tags = ["WrapNativeStableLending2", "base"];
deploy.dependencies = ["DependencyController"];
export default deploy;
