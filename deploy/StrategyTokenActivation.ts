import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { tokensPerNetwork } from "./TokenActivation";

const SimpleHoldingStrategy = "SimpleHoldingStrategy";

const strategiesPerNetwork: Record<string, Record<string, string[]>> = {
  hardhat: {
    USDC: [SimpleHoldingStrategy],
    ETH: [SimpleHoldingStrategy],
    WAVAX: [SimpleHoldingStrategy],
    USDT: [SimpleHoldingStrategy],
  },
};

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
  const Roles = await deployments.get("Roles");
  const roles = await ethers.getContractAt("Roles", Roles.address);

  const tokenAddresses = tokensPerNetwork[network.name];
  const tokenStrategies = strategiesPerNetwork[network.name];

  const args: [string[], string[], string[], string] = [
    [],
    [],
    [],
    roles.address,
  ];
  for (const [tokenName, strategies] of Object.entries(tokenStrategies)) {
    const tokenAddress = tokenAddresses[tokenName];
    for (const strategy of strategies) {
      const strategyAddress = (await deployments.get(strategy)).address;
      console.log(strategyAddress);
      const [isEnabled, tokenData] = await (
        await ethers.getContractAt(strategy, strategyAddress)
      ).checkApprovedAndEncode(tokenAddress);

      if (!isEnabled) {
        args[0].push(tokenAddress);
        args[1].push(strategyAddress);
        args[2].push(tokenData);
      }
    }
  }

  if (args[0].length > 0) {
    const StrategyTokenActivation = await deploy("StrategyTokenActivation", {
      from: deployer,
      args,
      log: true,
    });

    const dC = await ethers.getContractAt(
      "DependencyController",
      (
        await deployments.get("DependencyController")
      ).address
    );

    const tx = await dC.executeAsOwner(StrategyTokenActivation.address);
    console.log(`Executing strategy token activation as owner: ${tx.hash}`);
  }
};

deploy.tags = ["StrategyTokenActivation", "base"];
deploy.dependencies = ["TokenActivation", "DependencyController"];
deploy.runAtTheEnd = true;
export default deploy;
