import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { getAddress } from '@ethersproject/address';
import { parseEther } from '@ethersproject/units';

export const impersonateOwner = false;

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

  const roles = await deploy('Roles', {
    from: deployer,
    args: [deployer],
    log: true,
    skipIfAlreadyDeployed: true
  });

  const Roles = await ethers.getContractAt('Roles', roles.address);
  const currentOwner = await Roles.owner();

  if (impersonateOwner && getAddress(currentOwner) !== getAddress(deployer) && (await getChainId()) === '31337') {
    console.log('Impersonating owner');

    let tx = await (await ethers.getSigner(deployer)).sendTransaction({ to: currentOwner, value: parseEther('1')});
    await tx.wait();

    const provider = new ethers.providers.JsonRpcProvider(
      "http://localhost:8545"
    );
    await provider.send("hardhat_impersonateAccount", [currentOwner]);
    const signer = provider.getSigner(currentOwner);
    // await network.provider.request({
    //   method: 'hardhat_impersonateAccount',
    //   params: [currentOwner]
    // });
    // const signer = await ethers.provider.getSigner(currentOwner);

    tx = await Roles.connect(signer).transferOwnership(deployer);
    console.log(`Transferring ownership: ${tx.hash}`);
    await tx.wait();
  } else {
    console.log('Not impersonating owner');
  }
};
deploy.tags = ['Roles', 'local'];
export default deploy;


export function net(netname: string) {
  if (netname === 'localhost') {
    return 'avalanche';
  } else {
    return netname;
  }
}