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

  const ptAddress = (await deployments.get('MoreToken')).address;

  const xMore = await deploy('xMore', {
    from: deployer,
    args: [ptAddress],
    log: true,
    skipIfAlreadyDeployed: true
  });
};
deploy.tags = ['xMore', 'base'];
deploy.dependencies = ['MoreToken'];
deploy.runAtTheEnd = true;
export default deploy;
