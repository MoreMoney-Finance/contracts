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
  
  const LPTFlashLiquidation = await deploy('LPTFlashLiquidation', {
    from: deployer,
    args: [baseCurrency, usdt, curveZap, [dai, usdc, usdt], roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, LPTFlashLiquidation.address, 'LPTFlashLiquidation');
};
deploy.tags = ['LPTFlashLiquidation', 'base'];
deploy.dependencies = ['DependencyController', 'Stablecoin', 'CurvePool'];
export default deploy;
