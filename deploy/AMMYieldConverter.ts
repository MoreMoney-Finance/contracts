import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { manage, MINTER_BURNER } from './DependencyController';
import { tokenInitRecords, tokensPerNetwork } from './TokenActivation';
import ICurveZap from '../build/artifacts/interfaces/ICurveZap.sol/ICurveZap.json';
import IERC20 from '@openzeppelin/contracts/build/contracts/IERC20.json';
const { ethers } = require('hardhat');
import * as addresses from '../build/addresses.json';
import { parseEther, parseUnits } from '@ethersproject/units';

const deploy: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
  network
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments;
  const { deployer, amm1Router, amm2Router, curveZap } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const usdc = tokensPerNetwork[network.name].USDCe;
  const dai = tokensPerNetwork[network.name].DAIe;
  const usdt = tokensPerNetwork[network.name].USDTe;

  const AMMYieldConverter = await deploy('AMMYieldConverter', {
    from: deployer,
    args: [curveZap, [amm1Router, amm2Router], [dai, usdc, usdt], [1, 2, 3], roles.address],
    log: true,
    skipIfAlreadyDeployed: true
  });

  await manage(deployments, AMMYieldConverter.address, 'AMMYieldConverter');

  if (network.name == 'hardhat') {
    // const poolAddress = addresses['43114'].CurvePool;
    const poolAddress = await deployments.get('CurvePool');

    const tokenAddresses = tokensPerNetwork.avalanche;
    for (const [treasury, token, decimals] of [
      ['0xdF42181cdE9eCB156a5FdeF7561ADaB14937AA26', await ethers.getContractAt(IERC20.abi, tokenAddresses.USDTe), 6],
      ['0x20243F4081b0F777166F656871b61c2792FB4124', await ethers.getContractAt(IERC20.abi, tokenAddresses.DAIe), 18],
      ['0xa11Aa4b2AfD646BADDE5901e9a456a2F811e76Fa', await ethers.getContractAt(IERC20.abi, tokenAddresses.USDCe), 6]
    ]) {
      await network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [treasury]
      });
      const signer = await ethers.provider.getSigner(treasury);

      let tx = await token.connect(signer).transfer(deployer, parseUnits('100000', decimals));
      console.log(`Sending token from ${treasury} to ${deployer}:`);
      console.log(tx.hash);
      await tx.wait();

      tx = await token.approve(curveZap, parseUnits('1000000000', decimals));
      tx = await token.approve(poolAddress, parseUnits('1000000000', decimals));
      console.log('approving zap to spend', tx.hash);
      await tx.wait();
    }

    const dC = await ethers.getContractAt(
      'DependencyController',
      (
        await deployments.get('DependencyController')
      ).address
    );
    let tx = await dC.giveRole(MINTER_BURNER, deployer);
    console.log(`Giving minter/burner role: ${tx.hash}`);
    await tx.wait();
    const stable = await ethers.getContractAt('Stablecoin', (await deployments.get('Stablecoin')).address);
    tx = await stable.mint(deployer, parseEther('2000000'));
    console.log(`Minting lots of MONEY: ${tx.hash}`);
    await tx.wait();

    tx = await stable.approve(curveZap, parseEther('200000000000'));
    tx = await stable.approve(poolAddress, parseEther('200000000000'));
    console.log('approving zap', tx.hash);
    await tx.wait();

    const zap = await ethers.getContractAt(ICurveZap.abi, curveZap);
    console.log(`pool address: ${poolAddress}`);

    const addLiquidity = 'add_liquidity(address,uint256[4],uint256)';
    const args = [
      poolAddress,
      // [
      //   parseEther('0'),
      //   parseEther('0'), // dai
      //   parseUnits('0', 6), //usdc
      //   parseUnits('1', 6), // tether
      // ],
      [
        0,
        0,
        0,
        parseUnits('10000', 6) // tether
      ],
      1
    ];
    tx = await zap.functions[addLiquidity](...args);
    console.log(`Adding liquidity to pool: ${tx.hash}`);
    await tx.wait();

    tx = await stable.mint(poolAddress, parseEther('9000'));
    console.log(`Minting lots of MONEY: ${tx.hash}`);
    await tx.wait();
  }
};
deploy.tags = ['AMMYieldConverter', 'base'];
deploy.dependencies = ['DependencyController', 'Stablecoin', 'CurvePool'];
export default deploy;
