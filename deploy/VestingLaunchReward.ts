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

  const vestingCliff = net(network.name) === 'avalanche' ? 1643088249 : 240 + Math.round(Date.now() / 1000);
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
    // let tx = await pt.transfer(VestingLaunchReward.address, initialRewardAmount, { gasLimit: 8000000 });
    // console.log(`Transferring protocol token to vesting launch reward: ${tx.hash}`);
    // await tx.wait();

    const accounts = Object.keys(specialReward);
    const amounts = accounts.map(account => BigNumber.from(specialReward[account]));
    const tx = await vlr.mint(accounts, amounts);
    console.log(`Minting accounts in special rewards contract ${tx.hash}`);
    await tx.wait();

    console.log(`Deployer balance: ${formatEther(await vlr.balanceOf(deployer))}`);
    // const vestingPeriod = net(network.name) === 'hardhat' ? 60 * 60 * 24 : 90 * 60 * 60 * 24;
    // tx = await vlr.setVestingSchedule(initialRewardAmount.mul(10).div(100), vestingPeriod);
    // tx.wait();

    // console.log(`Setting vesting schedule: ${tx.hash}`);
  }
};
deploy.tags = ['VestingLaunchReward', 'base'];
deploy.dependencies = ['MoreToken'];
deploy.runAtTheEnd = true;
export default deploy;
