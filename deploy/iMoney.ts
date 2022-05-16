import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
const { ethers } = require("hardhat");

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const ptAddress = (await deployments.get("Roles")).address;
  const vemore = await deployments.get('VeMoreToken');

  const iMoney = await deploy("iMoney", {
    from: deployer,
    args: [vemore.address, ptAddress],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  if (network.name === 'hardhat') {
    const VeMore = await ethers.getContractAt('VeMoreToken', vemore.address);

    const tx = await VeMore.addListener(iMoney.address);
    console.log(`Setting iMoney up as listener: ${tx.hash}`);
    await tx.wait();
  } else {

    console.log();
    console.log();
    console.log('##########################################');
    console.log();
    console.log('Add iMoney as veMore listener:');
    console.log(`Call ${vemore.address} . addListener ( ${iMoney.address} )`);
    console.log();
    console.log('##########################################');
    console.log();
    console.log();
  }

  console.log(`Deploying iMoney contract: ${iMoney.address}`);
};
deploy.tags = ["iMoney", "base"];
deploy.dependencies = ["Roles", "Stablecoin", 'VeMoreToken'];
deploy.runAtTheEnd = true;
export default deploy;
