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

  const morePerSec = parseEther('1000000').div(30 * 24 * 60 * 60); 

  // I transfered ownership to multisig, now this breaks on avalanche
  // const MasterMore = await deploy("MasterMore", {
  //   from: deployer,
  //   proxy: {
  //     proxyContract: "OpenZeppelinTransparentProxy",
  //     owner: deployer,
  //     execute: {
  //       methodName: "initialize",
  //       args: [ptAddress, veMoreAddress, morePerSec, 700, parseInt((Date.now() / 1000).toString())],
  //     },
  //   },
  // });
  // create pool
  // const mc = await ethers.getContractAt('MasterMore', MasterMore.address);
  // let tx = await mc.add(100, jLPT, ethers.constants.AddressZero);
  // console.log(`Initializing MasterMore contract: ${MasterMore.address} ${tx.hash}`);
  // await tx.wait();

};
deploy.tags = ["MasterMore", "base"];
deploy.dependencies = ["DependencyController", "VeMoreToken", "MoreToken"];
export default deploy;
