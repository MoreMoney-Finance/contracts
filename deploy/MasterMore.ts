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
  const veMoreAddress = (await deployments.get("VeMoreToken")).address;
  console.log("ptAddress | MoreToken", ptAddress);

  const MasterMore = await deploy("MasterMore", {
    from: ,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [ptAddress, veMoreAddress, 1, 650, parseInt((Date.now() / 1000).toString())],
      },
    },
  });
  
  //create pool
  let tx = await (await ethers.getContractAt('MasterMore', MasterMore.address)).add(60, ptAddress, ethers.constants.AddressZero)
  await tx.wait();

  console.log(`Initializing MasterMore contract: ${MasterMore.address}`);
};
deploy.tags = ["MasterMore", "base"];
deploy.dependencies = ["DependencyController", "VeMoreToken", "MoreToken"];
export default deploy;
