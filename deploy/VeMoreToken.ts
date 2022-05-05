import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { assignMainCharacter, PROTOCOL_TOKEN } from "./DependencyController";
import { parseEther } from "@ethersproject/units";
const { ethers } = require("hardhat");

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network,
  ethers,
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const ptAddress = (await deployments.get("MoreToken")).address;

  console.log("ptAddress | MoreToken", ptAddress);

  const VeMoreToken = await deploy("VeMoreToken", {
    from: deployer,
    args: [],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  console.log(`Initializing VeMORE contract: ${VeMoreToken.address}`);

  const MasterMore = await deploy("BoostedMasterChefMore", {
    from: deployer,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [ptAddress, VeMoreToken.address, 1],
      },
    },
  });

  // const pt = await ethers.getContractAt("VeMore", ptAddress);
  // const tx = await pt.addListener(MasterMore.address);
  // console.log(`set Master More`);
  // await tx.wait();

  console.log(`Initializing MasterMore contract: ${MasterMore.address}`);
};
deploy.tags = ["VeMoreToken", "base"];
deploy.dependencies = ["DependencyController", "MoreToken"];
export default deploy;
