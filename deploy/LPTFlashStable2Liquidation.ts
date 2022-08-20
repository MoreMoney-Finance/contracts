import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { manage } from "./ContractManagement";
import { tokensPerNetwork } from "./TokenActivation";
import { net } from "./Roles";
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

  const netname = net(network.name);
  const usdc = tokensPerNetwork[netname].USDCe;
  const dai = tokensPerNetwork[netname].DAIe;
  const usdt = tokensPerNetwork[netname].USDTe;

  const LPTFlashStable2Liquidation = await deploy(
    "LPTFlashStable2Liquidation",
    {
      from: deployer,
      args: [baseCurrency, usdt, [dai, usdc, usdt], roles.address],
      log: true,
      skipIfAlreadyDeployed: true,
    }
  );

  await manage(
    deployments,
    LPTFlashStable2Liquidation.address,
    "LPTFlashStable2Liquidation"
  );
};
deploy.tags = ["LPTFlashStable2Liquidation", "base"];
deploy.dependencies = ["DependencyController", "Stablecoin", "CurvePool"];
export default deploy;
