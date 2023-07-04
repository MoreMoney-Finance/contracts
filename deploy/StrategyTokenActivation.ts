import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { chosenTokens, LPTokensByAMM, tokensPerNetwork } from './TokenActivation';
import path from 'path';
import * as fs from 'fs';
import IERC20 from '@openzeppelin/contracts/build/contracts/IERC20.json';
import { parseEther } from '@ethersproject/units';
import { net } from './Roles';
import { deployments, ethers } from 'hardhat';

const SimpleHoldingStrategy2 = { strategy: 'SimpleHoldingStrategy2', args: [0] };
const TraderJoeMasterChefStrategy = 'TraderJoeMasterChefStrategy';
const PangolinMiniChefStrategy = 'PangolinMiniChefStrategy';
const YYAVAXStrategy = {
  strategy: "YieldYakAVAXStrategy2",
  args: ["0xaAc0F2d0630d1D09ab2B5A400412a4840B866d95"],
};
const YYPermissiveStrategy = (underlyingAddress: string) => ({
  strategy: "YieldYakPermissiveStrategy2",
  args: [underlyingAddress]
});

const AltYYArbStrategy = {
  strategy: "AltYieldYakAVAXStrategy2",
  args: ["0x8B414448de8B609e96bd63Dcf2A8aDbd5ddf7fdd"]
}

const AltYieldYakStrategy2 = (underlyingAddress: string) => ({
  strategy: "AltYieldYakStrategy2",
  args: [underlyingAddress]
});

const YieldYakCompounderStrategy = {
  strategy: "YieldYakCompounderStrategy",
  args: ['0xc08986C33A714545330424fd5Fa132A8110E5E4F']
};


function TJMasterChef2Strategy(pid: number) {
  return { strategy: 'TraderJoeMasterChef2Strategy', args: [pid] };
}

function TJMasterChef3Strategy(pid: number) {
  return { strategy: TraderJoeMasterChefStrategy, args: [pid] };
}

function MultiTJMasterChef3Strategy(pid: number, additionalRewardTokens: string[]) {
  return { strategy: 'MultiTraderJoeMasterChef3Strategy', args: [pid, additionalRewardTokens] };
}

type StrategyConfig = {
  strategy: string;
  args: any[];
};

const strategiesPerNetwork: Record<string, Record<string, StrategyConfig[]>> = {
  hardhat: {
    // USDCe: [],
    // WETHe: [],
    ARB: [YYAVAXStrategy],
    USDTe: [SimpleHoldingStrategy2],
    yyArb: [SimpleHoldingStrategy2,YieldYakCompounderStrategy],
    PNG: [],
    BTCb: [AltYieldYakStrategy2("0xf9cD4Db17a3FB8bc9ec0CbB34780C91cE13ce767")],
    JOE: [AltYieldYakStrategy2("0x714e06410B4960D3C1FC033bCd53ad9EB2d1f874")],
    xJOE: [],
    wsMAXI: [],
    MAXI: [],
    'JPL-ARB-JOE': [],
    'JPL-ARB-PTP': [],
    'JPL-CAI-ARB': [],
    sAVAX: [AltYieldYakStrategy2("0xd0F41b1C9338eB9d374c83cC76b684ba3BB71557")],
    fsGLP: [YYPermissiveStrategy('0x9f637540149f922145c06e1aa3f38dcDc32Aff5C')]
  },
  avalanche: {
    // USDCe: [],
    // WETHe: [],
    ARB: [YYAVAXStrategy, AltYYArbStrategy],
    USDTe: [],
    yyArb: [SimpleHoldingStrategy2,YieldYakCompounderStrategy],
    PNG: [],
    BTCb: [AltYieldYakStrategy2("0xf9cD4Db17a3FB8bc9ec0CbB34780C91cE13ce767")],
    JOE: [AltYieldYakStrategy2("0x714e06410B4960D3C1FC033bCd53ad9EB2d1f874")],
    USDCe: [],
    QI: [],
    DAIe: [],
    xJOE: [],
    wsMAXI: [],
    'JPL-ARB-JOE': [],

    'JPL-ARB-USDCe': [],
    'JPL-ARB-USDTe': [],
    'JPL-ARB-WBTCe': [],
    'JPL-ARB-PTP': [],
    'JPL-CAI-ARB': [],
    sAVAX: [AltYieldYakStrategy2("0xd0F41b1C9338eB9d374c83cC76b684ba3BB71557")],
    fsGLP: [YYPermissiveStrategy('0x9f637540149f922145c06e1aa3f38dcDc32Aff5C')]
  },
  arbitrum: {
    sJOE: [AltYieldYakStrategy2("0x49e01Ade31690D286C5E820a8DAA4412125c7E7a")],
    sGLP: [YYPermissiveStrategy('0x9f637540149f922145c06e1aa3f38dcDc32Aff5C')]
  }
};

const lptStrategies: Record<string, Record<string, string>> = {
  hardhat: {
    JPL: TraderJoeMasterChefStrategy,
    PGL: PangolinMiniChefStrategy
  },
  avalanche: {
    JPL: TraderJoeMasterChefStrategy,
    PGL: PangolinMiniChefStrategy
  },
};

const YYStrats = {
  avalanche: {
    USDTe: '0x07B0E11D80Ccf75CB390c9Be6c27f329c119095A',
    QI: '0xbF5bFFbf7D94D3B29aBE6eb20089b8a9E3D229f7',
    BTCb: '0x8889Da43CeE581068C695A2c256Ba2D514608F4A',
    // PNG: '0x19707F26050Dfe7eb3C1b36E49276A088cE98752',
    // YAK: '0x0C4684086914D5B1525bf16c62a0FF8010AB991A',
    DAIe: '0xA914FEb3C4B580fF6933CEa4f39988Cd10Aa2985',
    USDCe: '0xf5Ac502C3662c07489662dE5f0e127799D715E1E',
    sAVAX: '0xc8cEeA18c2E168C6e767422c8d144c55545D23e9',

    yyArb: '0x4FB84317F1b8D14414B52d2Aa2dA097017960049',

    'JPL-ARB-JOE': '0x377DeD7fDD91a94bc360831DcE398ebEdB82cabA',
    'JPL-ARB-USDCe': '0xDc48D11e449343B2D9d75FACCcef361DF34739B1',
    'JPL-ARB-USDTe': '0x302d1596BB53fa64229bA5BdAA198f3c42Cd34e3',
    'JPL-CAI-ARB': '0xD390f59705f3F6d164d3C4b2C77d17224FCB033f',
  }, 
  arbitrum: {
    sJOE: '0x49e01Ade31690D286C5E820a8DAA4412125c7E7a',
    sGLP: '0x28f37fa106AA2159c91C769f7AE415952D28b6ac',
  }
};

// TODO: choice of strategies, tokens and deposit limits must be done by hand

const deploy: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  // switch the below if you want YY strategies for your LPT
  await augmentStrategiesPerNetworkWithYY(hre);
  // await augmentStrategiesPerNetworkWithLPT(hre);

  if (hre.network.name === 'hardhat') {
    tokensPerNetwork.hardhat.MORE = (await hre.deployments.get('MoreToken')).address;
  }

  const tokenStrategies = Object.entries(strategiesPerNetwork[net(hre.network.name)]);

  const STEP = 10;
  for (let i = 0; tokenStrategies.length > i; i += 10) {
    await runDeploy(tokenStrategies.slice(i, i + STEP), hre);
  }

  if (hre.network.name === 'hardhat' && false) {
    const { deployer, baseCurrency, amm2Router } = await hre.getNamedAccounts();
    const stableLendingAddress = (await hre.deployments.get('StableLending')).address;
    const stableLending2Address = (await hre.deployments.get('StableLending2')).address;

    const trancheId = await (
      await hre.ethers.getContractAt('TrancheIDService', (await hre.deployments.get('TrancheIDService')).address)
    ).viewNextTrancheId(stableLendingAddress);

    const trancheId2 = await (
      await hre.ethers.getContractAt('TrancheIDService', (await hre.deployments.get('TrancheIDService')).address)
    ).viewNextTrancheId(stableLending2Address);

    // const treasury = '0x3619157e14408eda5498ccfbeccfe80a8bb315d5';
    // await hre.network.provider.request({
    //   method: 'hardhat_impersonateAccount',
    //   params: [treasury]
    // });
    // const signer = await ethers.provider.getSigner(treasury);
    // const sAvax = await ethers.getContractAt(IERC20.abi, '0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE');
    // let tx = await sAvax.connect(signer).approve((await deployments.get('LiquidYieldStrategy')).address, parseEther('999999999999999999'));
    // console.log(`wallet approval: ${tx.hash}`);
    // await tx.wait();

    const wniL = await hre.ethers.getContractAt(
      'WrapNativeStableLending',
      (
        await hre.deployments.get('WrapNativeStableLending')
      ).address
    );
    const wniL2 = await hre.ethers.getContractAt(
      'WrapNativeStableLending2',
      (
        await hre.deployments.get('WrapNativeStableLending2')
      ).address
    );
    // const stableLending = (await hre.ethers.getContractAt(
    //   'StableLending',
    //   stableLendingAddress
    // )).connect(signer);

    // for (let i = 0; 3 > i; i++) {
    let tx = await wniL.mintDepositAndBorrow(
      (
        await hre.deployments.get('LiquidYieldStrategy')
      ).address,
      parseEther('1'),
      deployer,
      { value: parseEther('4500') }
    );

    let tx2 = await wniL2.mintDepositAndBorrow(
      (
        await hre.deployments.get('LiquidYieldStrategy')
      ).address,
      parseEther('1'),
      deployer,
      { value: parseEther('4500') }
    );

    //   console.log(`Depositing avax: ${tx.hash}`);
    //   await tx.wait();

    // const rebalancer = await ethers.getContractAt('LyRebalancer', (await deployments.get('LyRebalancer')).address);

    // tx = await stableLending.mintDepositAndBorrow(
    //   '0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE',
    //   (
    //     await hre.deployments.get('LiquidYieldStrategy')
    //   ).address,
    //   parseEther('3000'),
    //   parseEther('2000'),
    //   deployer
    // );

    // console.log(`Depositing sAvax: ${tx.hash}`);
    // await tx.wait();


    tx = await wniL.repayAndWithdraw(
      trancheId,
      parseEther('0.1'),
      parseEther('0.1'),
      deployer);

    console.log(`Repaying and withdrawing: ${tx.hash}`);
    await tx.wait();

    tx2 = await wniL2.repayAndWithdraw(
      trancheId2,
      parseEther('0.1'),
      parseEther('0.1'),
      deployer);

    console.log(`Repaying and withdrawing: ${tx2.hash}`);
    await tx2.wait();

    // const oracleRegistry = await hre.ethers.getContractAt(
    //   'OracleRegistry',
    //   (
    //     await hre.deployments.get('OracleRegistry')
    //   ).address
    // );
    // tx = await oracleRegistry.setBorrowable(baseCurrency, 6000);
    // await tx.wait();

    // const dfl = await hre.ethers.getContractAt('DirectFlashStableStableStableLiquidation', (await hre.deployments.get('DirectFlashStableLiquidation')).address);
    // tx = await dfl.liquidate(trancheId, amm2Router, deployer);
    // console.log('Liquidatiing: ', tx.hash);
    // await tx.wait();
  }
};

async function runDeploy(tokenStrategies: [string, StrategyConfig[]][], hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const { ARB } = tokensPerNetwork[net(hre.network.name)];
  const { network } = hre;

  const tokenDeployments: Record<string, string> = {};

  for (const [token, strategies] of tokenStrategies) {
    if (strategies.length === 0) {
      continue;
    }
    const tokenDeploy = await deployments.get(token);
    tokenDeployments[token] = tokenDeploy.address;

    const deployResults = await Promise.all(
      strategies.map((strategy) => {
        const deployArgs = [ARB, tokenDeploy.address, deployer, ...strategy.args];
        return deploy(strategy.strategy, {
          from: deployer,
          args: deployArgs,
          log: true
        });
      })
    );

    const configPath = path.join(
      __dirname,
      '..',
      'config',
      network.name,
      `deployed.${token.toLowerCase()}.json`
    );
    const currentDeployments = fs.existsSync(configPath)
      ? JSON.parse(fs.readFileSync(configPath, 'utf8'))
      : {};

    for (let i = 0; deployResults.length > i; i++) {
      const strategy = strategies[i];
      const deployment = deployResults[i];
      currentDeployments[strategy.strategy] = deployment.address;
    }

    fs.writeFileSync(configPath, JSON.stringify(currentDeployments, null, 2));
  }

  return tokenDeployments;
}

async function augmentStrategiesPerNetworkWithYY(hre: HardhatRuntimeEnvironment) {
  const networkName = net(hre.network.name);
  const tokens = tokensPerNetwork[networkName];
  const YYStrategies = Object.entries(YYStrats);

  for (const [token, yyStrategy] of YYStrategies[networkName]) {
    const strategies = strategiesPerNetwork[networkName][token] || [];
    strategies.push(YieldYakCompounderStrategy);
    strategiesPerNetwork[networkName][token] = strategies;
    tokens[token] = yyStrategy;
  }
}

export default deploy;
