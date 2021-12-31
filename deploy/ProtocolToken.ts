import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { assignMainCharacter, PROTOCOL_TOKEN } from './DependencyController';
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
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const totalSupply = parseEther('1000000000');

  const ProtocolToken = await deploy('ProtocolToken', {
    from: deployer,
    args: [totalSupply],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await assignMainCharacter(deployments, ProtocolToken.address, PROTOCOL_TOKEN, 'ProtocolToken');
};
deploy.tags = ['ProtocolToken', 'base'];
deploy.dependencies = ['DependencyController'];
export default deploy;
