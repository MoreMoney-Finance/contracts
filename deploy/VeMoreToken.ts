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

  const VeMoreToken = await deploy("VeMore", {
    from: deployer,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [
          ptAddress,
          // MasterMore.address,
          "0x0000000000000000000000000000000000000000",
        ],
      },
    },
  });

  console.log(`Initializing VeMORE contract: ${VeMoreToken.address}`);

  const MasterMore = await deploy("MasterMore", {
    from: deployer,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        methodName: "initialize",
        args: [
          ptAddress,
          VeMoreToken.address,
          1,
          800,
          Math.round(Date.now() / 1000),
        ],
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
