import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
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

  const ptAddress = (await deployments.get('MoreToken')).address;

  const VestingMoreToken = await deploy('VestingMoreToken', {
    from: deployer,
    args: [ptAddress],
    log: true,
    skipIfAlreadyDeployed: true
  });

  if (VestingMoreToken.newlyDeployed) {
    const pt = await ethers.getContractAt('MoreToken', ptAddress);

    const initialRewardAmount = parseEther('250000000');
    let tx = await pt.transfer(VestingMoreToken.address, initialRewardAmount, { gasLimit: 8000000 });
    console.log(`Transferring protocol token to vesting More Token: ${tx.hash}`);
    await tx.wait();
  }
};
deploy.tags = ['VestingMoreToken', 'base'];
deploy.dependencies = ['MoreToken'];
deploy.runAtTheEnd = true;
export default deploy;
