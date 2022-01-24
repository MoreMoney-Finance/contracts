import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage } from './ContractManagement';
import { formatEther, parseEther } from '@ethersproject/units';
import { net } from './Roles';
const { ethers } = require('hardhat');

import specialReward from '../data/special-reward.json';
import { BigNumber } from 'ethers';

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const ptAddress = (await deployments.get('MoreToken')).address;

  const VestingLaunchReward = await deploy('VestingLaunchReward', {
    from: deployer,
    args: [ptAddress],
    log: true,
    skipIfAlreadyDeployed: true
  });

  if (VestingLaunchReward.newlyDeployed) {
    const initialRewardAmount = Object.values(specialReward)
      .map(BigNumber.from)
      .reduce((agg, n) => agg.add(n));
    console.log('Initial reward amount:', formatEther(initialRewardAmount));
    const pt = await ethers.getContractAt('MoreToken', ptAddress);
    const vlr = await ethers.getContractAt('VestingLaunchReward', VestingLaunchReward.address);
    
    const accounts = Object.keys(specialReward);
    const amounts = accounts.map(account => BigNumber.from(specialReward[account]));
    let tx = await vlr.mint(accounts, amounts);
    console.log(`Minting accounts in special rewards contract ${tx.hash}`);
    await tx.wait();
    tx = await pt.transfer(VestingLaunchReward.address, initialRewardAmount, { gasLimit: 8000000 });
    console.log(`Transferring protocol token to vesting launch reward: ${tx.hash}`);
    await tx.wait();

    console.log(`Deployer balance: ${formatEther(await vlr.balanceOf(deployer))}`);
  }
};
deploy.tags = ['VestingLaunchReward', 'base'];
deploy.dependencies = ['MoreToken'];
deploy.runAtTheEnd = true;
export default deploy;
