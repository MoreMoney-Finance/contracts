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

  const AlphaNftLending = await deploy('AlphaNftLending', {
    from: deployer,
    args: ['Alpha NFT Dollar', 'AND'],
    log: true,
    skipIfAlreadyDeployed: true
  });
};
deploy.tags = ['AlphaNftLending', 'base'];
deploy.dependencies = [];
deploy.runAtTheEnd = true;
export default deploy;
