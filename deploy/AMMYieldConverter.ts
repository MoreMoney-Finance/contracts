import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './DependencyController';
import { tokenInitRecords, tokensPerNetwork } from './TokenActivation';
const { ethers } = require('hardhat');

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, amm1Router, amm2Router, curveZap } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const usdc = tokensPerNetwork[network.name].USDCe;
  const dai = tokensPerNetwork[network.name].DAIe;
  const usdt = tokensPerNetwork[network.name].USDTe;

  const AMMYieldConverter = await deploy('AMMYieldConverter', {
    from: deployer,
    args: [curveZap, [amm1Router, amm2Router], [dai, usdc, usdt], [1, 2, 3], roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, AMMYieldConverter.address);
};
deploy.tags = ['AMMYieldConverter', 'base'];
deploy.dependencies = ['DependencyController'];
export default deploy;
