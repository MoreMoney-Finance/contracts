import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("Roles", {
    from: deployer,
    args: [],
    log: true,
    skipIfAlreadyDeployed: true,
    deterministicDeployment: true,
  });
};
deploy.tags = ["Roles", "local"];
export default deploy;
