import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './ContractManagement';
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

  // string memory _name,
  // address _depositToken,
  // address _gmxProxy,
  // StrategySettings memory _strategySettings
  const gmxProxy = await deployments.get('GmxProxy');
  const GmxStrategyForGLP = await deploy('GmxStrategyForGLP', {
    from: deployer,
    args: [
      // _name
      "MoreMoney: GMX fsGLP",
      // _depositToken
      "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
      // _gmxProxy
      gmxProxy.address,
      [
        // minTokensToReinvest
        100000000000000,
        // adminFeeBips
        0,
        // devFeeBips
        600,
        // reinvestRewardBips
        400
      ]
    ],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, GmxStrategyForGLP.address, 'GmxStrategyForGLP');
};
deploy.tags = ['GmxStrategyForGLP', 'base'];
deploy.dependencies = ['DependencyController', 'GmxProxy'];
export default deploy;