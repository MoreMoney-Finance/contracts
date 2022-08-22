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
  const usdc = '0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664';
  const dai = tokensPerNetwork[netname].DAIe;
  const usdt = tokensPerNetwork[netname].USDTe;

  const DirectFlashStable2Liquidation = await deploy(
    "DirectFlashStable2Liquidation",
    {
      from: deployer,
      args: [baseCurrency, usdc, [dai, usdc, usdt], roles.address],
      log: true,
      skipIfAlreadyDeployed: true,
    }
  );

  await manage(
    deployments,
    DirectFlashStable2Liquidation.address,
    "DirectFlashStable2Liquidation"
  );
};
deploy.tags = ["DirectFlashStable2Liquidation", "base"];
deploy.dependencies = ["DependencyController", "Stablecoin", "CurvePool"];
export default deploy;
