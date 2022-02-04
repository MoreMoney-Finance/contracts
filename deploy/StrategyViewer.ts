import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
const { ethers } = require('hardhat');

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const StrategyViewer = await deploy('StrategyViewer', {
    from: deployer,
    args: [],
    log: true,
    skipIfAlreadyDeployed: true
  });
};

deploy.tags = ['StrategyViewer', 'base'];
deploy.dependencies = ['DependencyController', 'CurvePool'];
export default deploy;
