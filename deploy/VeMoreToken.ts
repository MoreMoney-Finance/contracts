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
          ptAddress,
          "0x0000000000000000000000000000000000000000",
        ],
      },
    },
  });

  console.log(`Initializing VeMORE contract: ${VeMoreToken.address}`);
};
deploy.tags = ["VeMoreToken", "base"];
deploy.dependencies = ["DependencyController", "MoreToken"];
export default deploy;
