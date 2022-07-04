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
  const { deployer, jLPT } = await getNamedAccounts();
  const ptAddress = (await deployments.get("MoreToken")).address;
  const veMoreAddress = (await deployments.get("VeMoreToken")).address;
  console.log("ptAddress | MoreToken", ptAddress);

  const morePerSec = Math.round(1000000 * 10 ** 18 / 30 / 24 / 60 / 60); 

  const MasterMore = await deploy("MasterMore", {
    from: deployer,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      owner: deployer,
      execute: {
        methodName: "initialize",
        args: [jLPT, veMoreAddress, morePerSec, 700, parseInt((Date.now() / 1000).toString())],
      },
    },
  });
  //create pool
  const mc = await ethers.getContractAt('MasterMore', MasterMore.address);
  let tx = await mc.add(100, jLPT, ethers.constants.AddressZero);
  console.log(`Initializing MasterMore contract: ${MasterMore.address} ${tx.hash}`);
  await tx.wait();

};
deploy.tags = ["MasterMore", "base"];
deploy.dependencies = ["DependencyController", "VeMoreToken", "MoreToken"];
export default deploy;
