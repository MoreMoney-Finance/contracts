import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
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

  const ptAddress = (await deployments.get("Roles")).address;

  const iMoney = await deploy("iMoney", {
    from: deployer,
    args: [ptAddress],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  console.log(`Deploying iMoney contract: ${iMoney.address}`);
};
deploy.tags = ["iMoney", "base"];
deploy.dependencies = ["Roles", "Stablecoin"];
deploy.runAtTheEnd = true;
export default deploy;
