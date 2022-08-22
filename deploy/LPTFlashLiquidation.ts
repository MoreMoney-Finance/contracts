import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './ContractManagement';
import { tokensPerNetwork } from './TokenActivation';
import { net } from './Roles';
const { ethers } = require('hardhat');

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, baseCurrency } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const netname = net(network.name);
  const usdc = tokensPerNetwork[netname].USDCe;
  const dai = tokensPerNetwork[netname].DAIe;
  const usdt = tokensPerNetwork[netname].USDTe;

  const LPTFlashLiquidation = await deploy('LPTFlashLiquidation', {
    from: deployer,
    args: [baseCurrency, usdt, [dai, usdc, usdt], roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, LPTFlashLiquidation.address, 'LPTFlashLiquidation');
};
deploy.tags = ['LPTFlashLiquidation', 'base'];
deploy.dependencies = ['DependencyController', 'Stablecoin', 'CurvePool'];
export default deploy;
