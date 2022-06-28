import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { MINTER_BURNER } from './DependencyController';
import { manage } from './ContractManagement';
import { tokenInitRecords, tokensPerNetwork } from './TokenActivation';
import ICurveZap from '../build/artifacts/interfaces/ICurveZap.sol/ICurveZap.json';
import IERC20 from '@openzeppelin/contracts/build/contracts/IERC20.json';
const { ethers } = require('hardhat');
import * as addresses from '../build/addresses.json';
import { parseEther, parseUnits } from '@ethersproject/units';
import { net } from './Roles';

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

  const netname = net(network.name);
  const usdc = tokensPerNetwork[netname].USDCe;
  const dai = tokensPerNetwork[netname].DAIe;
  const usdt = tokensPerNetwork[netname].USDTe;

  const AMMYieldConverter = await deploy('AMMYieldConverter', {
    from: deployer,
    args: [curveZap, [amm1Router, amm2Router], [dai, usdc, usdt], [1, 2, 3], roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, AMMYieldConverter.address, 'AMMYieldConverter');
};
deploy.tags = ['AMMYieldConverter', 'base'];
deploy.dependencies = ['DependencyController', 'Stablecoin', 'CurvePool'];
export default deploy;
