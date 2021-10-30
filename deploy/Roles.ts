import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network,
  ethers
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('Roles', {
    from: deployer,
    args: [deployer],
    log: true,
    skipIfAlreadyDeployed: true,
    deterministicDeployment: true
  });

  console.log(`deployer is: ${deployer}`);
  console.log(
    `owner of roles is: ${await (
      await ethers.getContractAt('Roles', (await deployments.get('Roles')).address)
    ).owner()}`
  );
};
deploy.tags = ['Roles', 'local'];
export default deploy;
