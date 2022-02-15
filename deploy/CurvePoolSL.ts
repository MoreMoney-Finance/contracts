import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './ContractManagement';
import IERC20 from '@openzeppelin/contracts/build/contracts/IERC20.json';
import { formatEther } from '@ethersproject/units';
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

  const CurvePoolSL = await deploy('CurvePoolSL', {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, CurvePoolSL.address, 'CurvePoolSL');

  // const sl = await ethers.getContractAt('CurvePoolSL', CurvePoolSL.address);

  // const stable = await ethers.getContractAt('Stablecoin', (await deployments.get('Stablecoin')).address);
  // console.log(`pool balance: ${formatEther(await stable.balanceOf((await deployments.get('CurvePool')).address))}`);
  // const tx = await sl.rebalance();
  // await tx.wait();
  // console.log(`pool balance: ${formatEther(await stable.balanceOf((await deployments.get('CurvePool')).address))}`);
};

deploy.tags = ['CurvePoolSL', 'base'];
deploy.dependencies = ['DependencyController', 'CurvePool'];
export default deploy;
