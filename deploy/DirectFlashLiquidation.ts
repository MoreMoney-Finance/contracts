import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './DependencyController';
import { tokensPerNetwork } from './TokenActivation';
const { ethers } = require('hardhat');

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, baseCurrency, curveZap } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const usdc = tokensPerNetwork[network.name].USDCe;
  const dai = tokensPerNetwork[network.name].DAIe;
  const usdt = tokensPerNetwork[network.name].USDTe;

  const DirectFlashLiquidation = await deploy('DirectFlashLiquidation', {
    from: deployer,
    args: [baseCurrency, usdt, curveZap, [dai, usdc, usdt], roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, DirectFlashLiquidation.address, 'DirectFlashLiquidation');
};
deploy.tags = ['DirectFlashLiquidation', 'base'];
deploy.dependencies = ['DependencyController', 'Stablecoin', 'CurvePool'];
export default deploy;
