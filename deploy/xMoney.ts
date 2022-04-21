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

  const ptAddress = (await deployments.get("Stablecoin")).address;

  const xMoney = await deploy("xMoney", {
    from: deployer,
    args: [ptAddress],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  console.log(`Deploying xMoney contract: ${xMoney.address}`);
};
deploy.tags = ["xMoney", "base"];
deploy.dependencies = ["MoreToken", "Stablecoin"];
deploy.runAtTheEnd = true;
export default deploy;
