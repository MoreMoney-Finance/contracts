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

  const ptAddress = "0x0f577433Bf59560Ef2a79c124E9Ff99fCa258948";

  const xMoney = await deploy("xMoney", {
    from: deployer,
    args: [ptAddress],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  console.log(`Deploying xMoney contract: ${xMoney.address}`);
};
deploy.tags = ["xMoney", "base"];
deploy.dependencies = ["MoreToken"];
deploy.runAtTheEnd = true;
export default deploy;
