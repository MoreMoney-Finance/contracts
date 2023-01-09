import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './ContractManagement';
import { BigNumber } from 'ethers';
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
      {
        // minTokensToReinvest
        minTokensToReinvest: BigNumber.from("100000000000000"),
        // adminFeeBips
        adminFeeBips: BigNumber.from("0"),
        // devFeeBips
        devFeeBips: BigNumber.from("600"),
        // reinvestRewardBips
        reinvestRewardBips: BigNumber.from("400")
      }
    ],
    log: true,
    skipIfAlreadyDeployed: true
  });
  console.log('GmxStrategyForGLP deployed to:', GmxStrategyForGLP.address);
  // await manage(deployments, GmxStrategyForGLP.address, 'GmxStrategyForGLP');
};
deploy.tags = ['GmxStrategyForGLP', 'base'];
deploy.dependencies = ['DependencyController', 'GmxProxy'];
deploy.runAtTheEnd = true;
export default deploy;