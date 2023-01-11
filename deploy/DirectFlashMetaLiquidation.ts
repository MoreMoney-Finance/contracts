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

  const DirectFlashMetaLiquidation = await deploy(
    "DirectFlashMetaLiquidation",
    {
      from: deployer,
      args: [baseCurrency, usdc, [dai, usdc, usdt], roles.address],
      log: true,
      skipIfAlreadyDeployed: true,
    }
  );

  await manage(
    deployments,
    DirectFlashMetaLiquidation.address,
    "DirectFlashMetaLiquidation"
  );
};
deploy.tags = ["DirectFlashMetaLiquidation", "base"];
deploy.dependencies = ["DependencyController", "Stablecoin", "CurvePool"];
export default deploy;
