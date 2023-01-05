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
  // address _rewardController,
  // address _tokenDelegator,
  // address _depositToken,
  // address _swapPairToken,
  // RewardSwapPairs[] memory _rewardSwapPairs,
  // address _avToken,
  // address _avDebtToken,
  // address _timelock,
  // LeverageSettings memory _leverageSettings,
  // StrategySettings memory _strategySettings
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
      "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
      // _swapPairToken
      "0xc31e54c7a869b9fcbecc14363cf510d1c41fa443",
      // rewardsPair
      [
        // _rewardToken
        "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
        // _swapPairToken
        "0xc31e54c7a869b9fcbecc14363cf510d1c41fa443",
      ],
      // _avToken
      "0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8",
      // _avDebtToken
      "0x0c84331e39d6658Cd6e6b9ba04736cC4c4734351",
      // timelock
      "",
      [
        // leverageSettings
        40000,
        // safetyFactor
        30000,
        // leverageBips
        100000000000000,
        // minMinting
        10000
      ],
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

  await manage(deployments, AaveV3StrategyV1.address, 'AaveV3StrategyV1');
};
deploy.tags = ['AaveV3StrategyV1', 'base'];
deploy.dependencies = ['DependencyController'];
export default deploy;