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
  network,
  ethers
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, amm2Router } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const totalSupplyNumber = 1000000000;

  const totalSupply = parseEther(totalSupplyNumber.toString());

  const MoreToken = await deploy('MoreToken', {
    from: deployer,
    args: [totalSupply],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await assignMainCharacter(deployments, MoreToken.address, PROTOCOL_TOKEN, 'MoreToken');

  if (MoreToken.newlyDeployed) {
    const abi = [
      {
        inputs: [
          { internalType: 'address', name: 'token', type: 'address' },
          { internalType: 'uint256', name: 'amountTokenDesired', type: 'uint256' },
          { internalType: 'uint256', name: 'amountTokenMin', type: 'uint256' },
          { internalType: 'uint256', name: 'amountAVAXMin', type: 'uint256' },
          { internalType: 'address', name: 'to', type: 'address' },
          { internalType: 'uint256', name: 'deadline', type: 'uint256' }
        ],
        name: 'addLiquidityAVAX',
        outputs: [
          { internalType: 'uint256', name: 'amountToken', type: 'uint256' },
          { internalType: 'uint256', name: 'amountAVAX', type: 'uint256' },
          { internalType: 'uint256', name: 'liquidity', type: 'uint256' }
        ],
        stateMutability: 'payable',
        type: 'function'
      }
    ];

    const router = await ethers.getContractAt(abi, amm2Router);

    const roughAVAXPrice = 100;
    const valuation = 30000000;
    const targetAvaxAmount = 0.01;
    const targetAvaxValue = targetAvaxAmount * roughAVAXPrice;
    const targetMoreAmount = (targetAvaxValue * totalSupplyNumber) / valuation;
    const avaxArg = parseEther(targetAvaxAmount.toString());
    const moreArg = parseEther(targetMoreAmount.toString());

    let tx = await (await ethers.getContractAt('MoreToken', MoreToken.address)).approve(amm2Router, moreArg);
    await tx.wait();
    tx = await router.addLiquidityAVAX(MoreToken.address, moreArg, moreArg, avaxArg, deployer, Date.now() + 60 * 60, {
      value: avaxArg
    });
    console.log(`Initializing MORE pool: ${tx.hash}`);
    await tx.wait();
  }
};
deploy.tags = ['MoreToken', 'base'];
deploy.dependencies = ['DependencyController'];
export default deploy;
