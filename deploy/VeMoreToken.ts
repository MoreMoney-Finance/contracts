import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { assignMainCharacter, PROTOCOL_TOKEN } from "./DependencyController";
import { parseEther } from "@ethersproject/units";
const { ethers } = require("hardhat");

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network,
  ethers,
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, amm2Router } = await getNamedAccounts();
  const Roles = await deployments.get("Roles");
  const roles = await ethers.getContractAt("Roles", Roles.address);

  const totalSupplyNumber = 1000000000;

  const totalSupply = parseEther(totalSupplyNumber.toString());

  const VeMoreToken = await deploy("VeMore", {
    from: deployer,
    args: [],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  console.log(`Initializing VeMORE contract: ${VeMoreToken.address}`);
  // await assignMainCharacter(deployments, VeMoreToken.address, PROTOCOL_TOKEN, 'VeMore');

  // if (VeMoreToken.newlyDeployed) {
  //   console.log('newlyDeployed');
  //   const abi = [
  //     {
  //       inputs: [
  //         { internalType: 'address', name: 'token', type: 'address' },
  //         { internalType: 'uint256', name: 'amountTokenDesired', type: 'uint256' },
  //         { internalType: 'uint256', name: 'amountTokenMin', type: 'uint256' },
  //         { internalType: 'uint256', name: 'amountAVAXMin', type: 'uint256' },
  //         { internalType: 'address', name: 'to', type: 'address' },
  //         { internalType: 'uint256', name: 'deadline', type: 'uint256' }
  //       ],
  //       name: 'addLiquidityAVAX',
  //       outputs: [
  //         { internalType: 'uint256', name: 'amountToken', type: 'uint256' },
  //         { internalType: 'uint256', name: 'amountAVAX', type: 'uint256' },
  //         { internalType: 'uint256', name: 'liquidity', type: 'uint256' }
  //       ],
  //       stateMutability: 'payable',
  //       type: 'function'
  //     }
  //   ];

  //   const router = await ethers.getContractAt(abi, amm2Router);

  //   const roughAVAXPrice = 100;
  //   const valuation = 30000000;
  //   const targetAvaxAmount = 0.01;
  //   const targetAvaxValue = targetAvaxAmount * roughAVAXPrice;
  //   const targetMoreAmount = (targetAvaxValue * totalSupplyNumber) / valuation;
  //   const avaxArg = parseEther(targetAvaxAmount.toString());
  //   const moreArg = parseEther(targetMoreAmount.toString());

  //   console.log(`Initializing VeMORE contract: ${VeMoreToken.address}`);
  // }
};
deploy.tags = ["VeMoreToken", "base"];
deploy.dependencies = ["DependencyController"];
export default deploy;
