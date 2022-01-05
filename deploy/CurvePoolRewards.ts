import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './DependencyController';
import { parseEther } from '@ethersproject/units';
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
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const vestingCliff = network.name === 'avalanche'
    ? 1643088249
    : 240 + Math.round(Date.now() / 1000);

  const vestingPeriod = network.name === 'hardhat'
    ? 60
    : 40 * 60 * 60 * 24;

    const CurvePoolRewards = await deploy('CurvePoolRewards', {
    from: deployer,
    args: [vestingCliff, vestingPeriod, roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, CurvePoolRewards.address, 'CurvePoolRewards');

  if (network.name === 'hardhat') {
    const ptAddress = (await deployments.get('ProtocolToken')).address;
    const pt = await ethers.getContractAt('ProtocolToken', ptAddress);
    const cpr = await ethers.getContractAt('CurvePoolRewards', CurvePoolRewards.address);
    let tx = await pt.transfer(CurvePoolRewards.address, parseEther('2000'));
    console.log(`Transferring protocol token to curve pool: ${tx.hash}`);
    await tx.wait();

    tx = await cpr.notifyRewardAmount(parseEther('1000'));
    console.log(`Notifying rewards contract of amount ${tx.hash}`);
    await tx.wait();
  }
};
deploy.tags = ['CurvePoolRewards', 'base'];
deploy.dependencies = [
  'DependencyController',
  'CurvePool',
  'TokenActivation',
  'ProtocolToken',
  'Stablecoin',
  'CurveLPTOracle',
  'EquivalentScaledOracle'
];
deploy.runAtTheEnd = true;
export default deploy;
