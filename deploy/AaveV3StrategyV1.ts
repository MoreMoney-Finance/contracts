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

  const AaveV3StrategyV1 = await deploy('AaveV3StrategyV1', {
    from: deployer,
    args: [
      // _name
      "MoreMoney: Aave ETH",
      // _rewardController
      "0x929EC64c34a17401F460460D4B9390518E5B473e",
      // _tokenDelegator
      "0x794a61358D6845594F94dc1DB02A252b5b4814aD", 
      // _depositToken
      "0xff970a61a04b1ca14834a43f5de4533ebddb5cc8",
      // _swapPairToken
      "0xc31e54c7a869b9fcbecc14363cf510d1c41fa443",
      // rewardsPair
      [{
        // _rewardToken
        reward: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
        // _swapPairToken
        swapPair:"0xc31e54c7a869b9fcbecc14363cf510d1c41fa443",
      }],
      // _avToken
      "0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8",
      // _avDebtToken
      "0x0c84331e39d6658Cd6e6b9ba04736cC4c4734351",
      {
        // leverageSettings
        leverageLevel: BigNumber.from("40000"),
        // safetyFactor
        safetyFactor: BigNumber.from("30000"),
        // leverageBips
        leverageBips: BigNumber.from("100000000000000"),
        // minMinting
        minMinting: BigNumber.from("10000"),
      },
      {
        // minTokensToReinvest
        minTokensToReinvest:BigNumber.from("100000000000000"),
        // adminFeeBips
        adminFeeBips:BigNumber.from("0"),
        // devFeeBips
        devFeeBips:BigNumber.from("600"),
        // reinvestRewardBips
        reinvestRewardBips: BigNumber.from("400"),
      }
    ],
    log: true,
    skipIfAlreadyDeployed: true
  });
  console.log('AaveV3StrategyV1 deployed to:', AaveV3StrategyV1.address);
  // await manage(deployments, AaveV3StrategyV1.address, 'AaveV3StrategyV1');
};
deploy.tags = ['AaveV3StrategyV1', 'base'];
deploy.dependencies = ['DependencyController'];
deploy.runAtTheEnd = true;
export default deploy;