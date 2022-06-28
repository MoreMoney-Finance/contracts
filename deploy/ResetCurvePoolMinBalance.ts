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
  const Roles = await deployments.get('Roles');
  const dC = await deployments.get('DependencyController');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const ResetCurvePoolMinBalance = await deploy('ResetCurvePoolMinBalance', {
    from: deployer,
    args: [roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  if (ResetCurvePoolMinBalance.newlyDeployed) {
    console.log();
    console.log();
    console.log('##########################################');
    console.log();
    console.log('Reset Curve pool min balance:');
    console.log(`Call ${dC.address} . execute ( ${ResetCurvePoolMinBalance.address} )`);
    console.log();
    console.log('##########################################');
    console.log();
    console.log();
  }
};
deploy.tags = ['ResetCurvePoolMinBalance', 'base'];
deploy.dependencies = ['DependencyController', 'Stablecoin', 'CurvePool'];
export default deploy;
