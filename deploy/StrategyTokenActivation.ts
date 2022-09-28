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

const AltYYAvaxStrategy = {
  strategy: "AltYieldYakAVAXStrategy2",
  args: ["0x8B414448de8B609e96bd63Dcf2A8aDbd5ddf7fdd"]
}

const AltYieldYakStrategy2 = (underlyingAddress: string) => ({
  strategy: "AltYieldYakStrategy2",
  args: [underlyingAddress]
});


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
    WAVAX: [YYAVAXStrategy],
    USDTe: [SimpleHoldingStrategy2],
    yyAvax: [SimpleHoldingStrategy2, AltYieldYakStrategy2("0x4FB84317F1b8D14414B52d2Aa2dA097017960049")],
    PNG: [],
    BTCb: [AltYieldYakStrategy2("0xf9cD4Db17a3FB8bc9ec0CbB34780C91cE13ce767")],
    JOE: [],
    xJOE: [],
    wsMAXI: [],
    MAXI: [],
    'JPL-WAVAX-JOE': [],
    'JPL-WAVAX-PTP': [],
    'JPL-CAI-WAVAX': [],
    sAVAX: [AltYieldYakStrategy2("0xd0F41b1C9338eB9d374c83cC76b684ba3BB71557")],
    fsGLP: [YYPermissiveStrategy('0x9f637540149f922145c06e1aa3f38dcDc32Aff5C')]
  },
  avalanche: {
    // USDCe: [],
    // WETHe: [],
    WAVAX: [YYAVAXStrategy, AltYYAvaxStrategy],
    USDTe: [],
    yyAvax: [SimpleHoldingStrategy2,AltYieldYakStrategy2("0x4FB84317F1b8D14414B52d2Aa2dA097017960049")],
    PNG: [],
    BTCb: [AltYieldYakStrategy2("0xf9cD4Db17a3FB8bc9ec0CbB34780C91cE13ce767")],
    JOE: [],
    USDCe: [],
    QI: [],
    DAIe: [],
    xJOE: [],
    wsMAXI: [],
    'JPL-WAVAX-JOE': [],

    'JPL-WAVAX-USDCe': [],
    'JPL-WAVAX-USDTe': [],
    'JPL-WAVAX-WBTCe': [],
    'JPL-WAVAX-PTP': [],
    'JPL-CAI-WAVAX': [],
    sAVAX: [AltYieldYakStrategy2("0xd0F41b1C9338eB9d374c83cC76b684ba3BB71557")],
    fsGLP: [YYPermissiveStrategy('0x9f637540149f922145c06e1aa3f38dcDc32Aff5C')]
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
  USDTe: '0x07B0E11D80Ccf75CB390c9Be6c27f329c119095A',
  QI: '0xbF5bFFbf7D94D3B29aBE6eb20089b8a9E3D229f7',
  BTCb: '0x8889Da43CeE581068C695A2c256Ba2D514608F4A',
  // PNG: '0x19707F26050Dfe7eb3C1b36E49276A088cE98752',
  // YAK: '0x0C4684086914D5B1525bf16c62a0FF8010AB991A',
  DAIe: '0xA914FEb3C4B580fF6933CEa4f39988Cd10Aa2985',
  USDCe: '0xf5Ac502C3662c07489662dE5f0e127799D715E1E',
  sAVAX: '0xc8cEeA18c2E168C6e767422c8d144c55545D23e9',


  'JPL-WAVAX-JOE': '0x377DeD7fDD91a94bc360831DcE398ebEdB82cabA',
  'JPL-WAVAX-USDCe': '0xDc48D11e449343B2D9d75FACCcef361DF34739B1',
  'JPL-WAVAX-USDTe': '0x302d1596BB53fa64229bA5BdAA198f3c42Cd34e3',
  'JPL-CAI-WAVAX': '0xD390f59705f3F6d164d3C4b2C77d17224FCB033f'
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
  const { getNamedAccounts, deployments, getChainId, getUnnamedAccounts, network, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const Roles = await deployments.get('Roles');
  const roles = await ethers.getContractAt('Roles', Roles.address);

  const tokenAddresses = tokensPerNetwork[net(network.name)];

  const dC = await ethers.getContractAt(
    'DependencyController',
    (
      await deployments.get('DependencyController')
    ).address
  );

  const args: [string[], string[], string[], string] = [[], [], [], roles.address];
  for (const [tokenName, strategies] of tokenStrategies) {
    const tokenAddress = tokenAddresses[tokenName];

    for (const strategy of strategies) {
      const strategyAddress = (await deployments.get(strategy.strategy))
        .address;

      const [isEnabled, tokenData] = await (
        await ethers.getContractAt(strategy.strategy, strategyAddress)
      ).checkApprovedAndEncode(tokenAddress, ...strategy.args);

      if (!isEnabled) {
        args[0].push(tokenAddress);
        args[1].push(strategyAddress);
        args[2].push(tokenData);

        console.log(`addded ${tokenName} for strategy ${strategy.strategy}`);
      }
    }
  }

  if (args[0].length > 0) {
    const StrategyTokenActivation = await deploy('StrategyTokenActivation', {
      from: deployer,
      args,
      log: true,
      skipIfAlreadyDeployed: false
    });

    console.log();
    console.log();
    console.log('##########################################');
    console.log();
    console.log('StrategyTokenActivation:');
    console.log(`Call ${dC.address} . execute ( ${StrategyTokenActivation.address} )`);
    console.log();
    console.log('##########################################');
    console.log();
    console.log();

    if (network.name === 'localhost') {
      const Roles = await ethers.getContractAt('Roles', roles.address);
      const currentOwner = await Roles.owner();

      let tx = await (
        await ethers.getSigner(deployer)
      ).sendTransaction({ to: currentOwner, value: parseEther('1') });
      await tx.wait();

      const provider = new ethers.providers.JsonRpcProvider(
        'http://localhost:8545'
      );
      await provider.send('hardhat_impersonateAccount', [currentOwner]);
      const signer = provider.getSigner(currentOwner);

      if (
        (await ethers.provider.getCode(StrategyTokenActivation.address)) !==
        '0x'
      ) {
        tx = await dC
          .connect(signer)
          .executeAsOwner(StrategyTokenActivation.address);
        console.log(`Running strategy token activation: ${tx.hash}`);
        await tx.wait();
      }
    } else if (network.name === 'hardhat') {
      if (
        (await ethers.provider.getCode(StrategyTokenActivation.address)) !==
        '0x'
      ) {
        const tx = await dC.executeAsOwner(StrategyTokenActivation.address, {
          gasLimit: 8000000,
        });
        console.log(`Executing strategy token activation as owner: ${tx.hash}`);
        await tx.wait();
      }
    }
  }
}

deploy.tags = ['StrategyTokenActivation', 'base'];
deploy.dependencies = ['TokenActivation', 'ContractManagement', 'DependencyController'];
deploy.runAtTheEnd = true;
export default deploy;

// For MasterChef:
// per each masterchef pull all the PIDs and cache in a JSON file
// go through all the pairs generated per DEX
// look up their addresses in that PID cache
// activate if necessary

async function augmentStrategiesPerNetworkWithLPT(hre: HardhatRuntimeEnvironment) {
  const networkName = net(hre.network.name);
  const chainId = await hre.getChainId();
  const tokenStrategies = strategiesPerNetwork[networkName];

  const lpTokensPath = path.join(__dirname, '../build/lptokens.json');
  const lpTokensByAMM: LPTokensByAMM = JSON.parse(
    (await fs.promises.readFile(lpTokensPath)).toString()
  );

  const chosenOnes = chosenTokens[networkName];
  for (const [amm, strategyName] of Object.entries(
    lptStrategies[networkName]
  )) {
    const lpRecords = lpTokensByAMM[chainId][amm];

    for (const [jointTicker, lpRecord] of Object.entries(lpRecords)) {
      if (chosenOnes[jointTicker]) {
        if (typeof lpRecord.pid === 'number') {
          const depositLimit = (
            await (
              await hre.ethers.getContractAt(IERC20.abi, lpRecord.pairAddress)
            ).totalSupply()
          ).div(10);
          tokenStrategies[jointTicker] = [
            { strategy: strategyName, args: [lpRecord.pid] },
          ];
          tokensPerNetwork[networkName][jointTicker] = lpRecord.pairAddress!;
        } else if (lpRecord.stakingContract) {
          const depositLimit = (
            await (
              await hre.ethers.getContractAt(IERC20.abi, lpRecord.pairAddress)
            ).totalSupply()
          ).div(10);
          tokenStrategies[jointTicker] = [
            { strategy: strategyName, args: [lpRecord.stakingContract] },
          ];
          tokensPerNetwork[networkName][jointTicker] = lpRecord.pairAddress!;
        }
      }
    }
  }
}

async function augmentStrategiesPerNetworkWithYY(
  hre: HardhatRuntimeEnvironment
) {
  const netname = net(hre.network.name);
  const tokenStrategies = strategiesPerNetwork[netname];
  console.log(`network name: ${netname}`);
  if (['avalanche', 'localhost', 'hardhat', 'local'].includes(netname)) {
    const chosenOnes = chosenTokens[netname];

    const { token2strategy } = await getYYStrategies(hre);
    for (const [tokenName, tokenAddress] of Object.entries(
      tokensPerNetwork[netname]
    )) {
      const stratAddress = token2strategy[tokenAddress];
      if (stratAddress && chosenOnes[tokenName]) {
        const depositLimit = (
          await (
            await hre.ethers.getContractAt(IERC20.abi, stratAddress)
          ).totalSupply()
        ).div(10);
        tokenStrategies[tokenName] = [
          { strategy: "YieldYakStrategy2", args: [stratAddress] },
          ...(tokenStrategies[tokenName] ?? []),
        ];
      }
    }
  }
}

async function getYYStrategies(hre: HardhatRuntimeEnvironment) {
  const token2strategy: Record<string, string> = {};
  const tokenAddresses = tokensPerNetwork[net(hre.network.name)];

  Object.entries(YYStrats).forEach(([tokenName, stratAddress]) => {
    token2strategy[tokenAddresses[tokenName]] = stratAddress;
  });

  return { token2strategy };
}

// const yyAPI = 'https://staging-api-dot-avalanche-304119.ew.r.appspot.com/apys';
// async function getYYStrategies(hre: HardhatRuntimeEnvironment) {
//   console.log(`Getting yy strategy data`);
//   const yyStratPath = path.join(__dirname, '../build/yy-strategies.json');
//   if (fs.existsSync(yyStratPath)) {
//     console.log(`Reading YY strategies from ${yyStratPath}`);
//     return JSON.parse((await fs.promises.readFile(yyStratPath)).toString());
//   } else {
//     console.log(`Fetching YY strategies from API`);
//     const response = await fetch(yyAPI);

//     const token2strategy: Record<string, string> = {};
//     const strategy2timestamp: Record<string, number> = {};

//     for (const [stratAddress, metadata] of Object.entries(await response.json()) as any) {
//       const strat = await hre.ethers.getContractAt('IYakStrategy', stratAddress);
//       try {
//         const token: string = getAddress(await strat.depositToken());

//         const extantStrat = token2strategy[token];
//         if (!extantStrat || metadata.lastReinvest.timestamp > strategy2timestamp[extantStrat]) {
//           token2strategy[token] = stratAddress;
//         }

//         strategy2timestamp[stratAddress] = metadata.lastReinvest.timestamp;
//       } catch (e) {
//         console.error(e);
//       }
//     }
//     await fs.promises.writeFile(
//       yyStratPath,
//       JSON.stringify(
//         {
//           token2strategy,
//           strategy2timestamp
//         },
//         null,
//         2
//       )
//     );

//     return {
//       token2strategy,
//       strategy2timestamp
//     };
//   }
// }
