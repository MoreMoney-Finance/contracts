// iterate over, group them up
// test their parameters all over the place?
// perhaps another central registry? -- to make idempotency easier

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { BigNumber } from "@ethersproject/bignumber";
import { parseEther, parseUnits } from "@ethersproject/units";
import IUniswapV2Factory from "@uniswap/v2-core/build/IUniswapV2Factory.json";

const baseCurrency = {
  kovan: "WETH",
  mainnet: "WETH",
  avalanche: "WAVAX",
  localhost: "WETH",
  matic: "WETH",
  bsc: "WBNB",
};

export const tokensPerNetwork: Record<string, Record<string, string>> = {
  localhost: {
    WAVAX: "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7",
    ETH: "0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB",
    // PNG: '0x60781C2586D68229fde47564546784ab3fACA982',
    // USDT: '0xc7198437980c041c805A1EDcbA50c1Ce5db95118',
    // YAK: '0x59414b3089ce2AF0010e7523Dea7E2b35d776ec7',
    // QI: '0x8729438EB15e2C8B576fCc6AeCdA6A148776C0F5',
    // XAVA: '0xd1c3f94DE7e5B45fa4eDBBA472491a9f4B166FC4',
    // JOE: '0x6e84a6216ea6dacc71ee8e6b0a5b7322eebc0fdd',
    USDC: "0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664",
    // DAI: '0xd586e7f844cea2f87f50152665bcbc2c279d8d70',
    // WBTC: '0x50b7545627a5162f82a992c33b87adc75187b218'
  },
  avalanche: {
    WAVAX: "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7",
    ETH: "0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB",
    // PNG: '0x60781C2586D68229fde47564546784ab3fACA982',
    // USDT: '0xc7198437980c041c805A1EDcbA50c1Ce5db95118',
    // YAK: '0x59414b3089ce2AF0010e7523Dea7E2b35d776ec7',
    // QI: '0x8729438EB15e2C8B576fCc6AeCdA6A148776C0F5',
    // XAVA: '0xd1c3f94DE7e5B45fa4eDBBA472491a9f4B166FC4',
    // JOE: '0x6e84a6216ea6dacc71ee8e6b0a5b7322eebc0fdd',
    USDC: "0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664",
    // DAI: '0xd586e7f844cea2f87f50152665bcbc2c279d8d70',
    // WBTC: '0x50b7545627a5162f82a992c33b87adc75187b218'
  },
};

type OracleConfig = (
  primary: boolean,
  tokenAddress: string,
  record: TokenInitRecord,
  allTokens: Record<string, string>,
  hre: HardhatRuntimeEnvironment
) => Promise<[string, any[]]>;

export type TokenInitRecord = {
  decimals?: number;
  oracle: OracleConfig;
  debtCeiling: number;
  mintingFeePercent?: number;
  colRatioPercent?: number;
  additionalOracles?: [string, OracleConfig][];
};

function ChainlinkConfig(oracle: string): OracleConfig {
  return async (_primary, tokenAddress, record, _allTokens, hre) => [
    "ChainlinkOracle",
    [
      tokenAddress,
      (await hre.deployments.get("Stablecoin")).address,
      oracle,
      record.decimals ?? 18,
    ],
  ];
}

async function getPair(
  hre: HardhatRuntimeEnvironment,
  factoryContract: string,
  tokenA: string,
  tokenB: string
) {
  const [token0, token1] =
    tokenA.toLowerCase() < tokenB.toLowerCase()
      ? [tokenA, tokenB]
      : [tokenB, tokenA];
  return (
    await hre.ethers.getContractAt(IUniswapV2Factory.abi, factoryContract)
  ).getPair(token0, token1);
}

function TwapConfig(
  factoryContract: string,
  pegCurrency?: string
): OracleConfig {
  return async (_primary, tokenAddress, _record, allTokens, hre) => {
    const peg = pegCurrency
      ? allTokens[pegCurrency]
      : (await hre.deployments.get("Stablecoin")).address;
    return [
      "TwapOracle",
      [
        tokenAddress,
        peg,
        await getPair(hre, factoryContract, tokenAddress, peg),
        true,
      ],
    ];
  };
}

function TraderTwapConfig(pegCurrency?: string): OracleConfig {
  return TwapConfig("0x9Ad6C38BE94206cA50bb0d90783181662f0Cfa10", pegCurrency);
}

function EquivalentConfig(scale?: number, pegCurrency?: string): OracleConfig {
  return async (primary, tokenAddress, record, allTokens, hre) => [
    "EquivalentScaledOracle",
    [
      tokenAddress,
      pegCurrency
        ? allTokens[pegCurrency]
        : (await hre.deployments.get("Stablecoin")).address,
      parseUnits((scale ?? "1").toString(), record.decimals ?? 18),
      parseEther("1"),
    ],
  ];
}

export const tokenInitRecords: Record<string, TokenInitRecord> = {
  WAVAX: {
    oracle: ChainlinkConfig("0x0a77230d17318075983913bc2145db16c7366156"),
    debtCeiling: 1000,
    additionalOracles: [["WAVAX", TraderTwapConfig("USDC")]],
  },
  ETH: {
    oracle: ChainlinkConfig("0x976b3d034e162d8bd72d6b9c989d545b839003b0"),
    debtCeiling: 100,
    additionalOracles: [["ETH", TraderTwapConfig("USDC")]],
  },
  USDC: {
    oracle: EquivalentConfig(),
    debtCeiling: 1000,
    decimals: 6,
  },
};

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {
    getNamedAccounts,
    deployments,
    getChainId,
    getUnnamedAccounts,
    network,
    ethers,
  } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const Roles = await deployments.get("Roles");
  const roles = await ethers.getContractAt("Roles", Roles.address);

  const targetTokens: string[] = [];
  const debtCeilings: BigNumber[] = [];
  const feesPerMil: BigNumber[] = [];

  const IL = await ethers.getContractAt(
    "IsolatedLending",
    (
      await deployments.get("IsolatedLending")
    ).address
  );

  const dC = await ethers.getContractAt(
    "DependencyController",
    (
      await deployments.get("DependencyController")
    ).address
  );

  // first go over all the oracles
  const allOracleActivations = await collectAllOracleCalls(
    hre,
    tokensPerNetwork[network.name]
  );

  for (const [oracleAddress, oArgs] of Object.entries(allOracleActivations)) {
    const OracleActivation = await deploy("OracleActivation", {
      from: deployer,
      args: [
        oracleAddress,
        oArgs.tokens,
        oArgs.pegCurrencies,
        oArgs.colRatios,
        oArgs.data,
        roles.address,
      ],
      log: true,
      deterministicDeployment: true,
    });

    const tx = await dC.executeAsOwner(OracleActivation.address);
    console.log(`Executing oracle activation for ${oracleAddress}: ${tx.hash}`);
  }

  for (const [tokenName, tokenAddress] of Object.entries(
    tokensPerNetwork[network.name]
  )) {
    const initRecord = tokenInitRecords[tokenName];
    const debtCeiling = parseUnits(initRecord.debtCeiling.toString(), 6);
    const mintingFee = BigNumber.from(
      ((initRecord.mintingFeePercent ?? 1) * 10).toString()
    );

    const [
      ilDebtCeiling,
      ilTotalDebt,
      ilFeePerMil,
      ilStabilityFee,
      ilMintingFee,
      ilColRatio,
    ] = await IL.viewILMetadata(tokenAddress);
    if (!(debtCeiling.eq(ilDebtCeiling) && mintingFee.eq(ilMintingFee))) {
      targetTokens.push(tokenAddress);
      debtCeilings.push(debtCeiling);
      feesPerMil.push(mintingFee);
    }
  }
  const args = [targetTokens, debtCeilings, feesPerMil, roles.address];

  if (targetTokens.length > 0) {
    const TokenActivation = await deploy("TokenActivation", {
      from: deployer,
      args,
      log: true,
      deterministicDeployment: true,
    });

    const tx = await dC.executeAsOwner(TokenActivation.address);
    console.log(`Executing token activation: ${tx.hash}`);
  }
};

deploy.tags = ["TokenActivation", "base"];
deploy.dependencies = [
  "DependencyController",
  "OracleRegistry",
  "TwapOracle",
  "ChainlinkOracle",
  "EquivalentScaledOracle",
  "ProxyOracle",
  "TwapOracle",
  "UniswapV2LPTOracle",
];
export default deploy;

async function collectAllOracleCalls(
  hre: HardhatRuntimeEnvironment,
  tokenAddresses: Record<string, string>
) {
  type OracleActivationArgs = {
    tokens: string[];
    pegCurrencies: string[];
    colRatios: BigNumber[];
    data: string[];
  };
  const oracleActivationArgs: Record<string, OracleActivationArgs> = {};

  async function processOracleCalls(
    oracle: OracleConfig,
    tokenName: string,
    tokenAddress: string
  ) {
    const initRecord = tokenInitRecords[tokenName];

    const [oracleName, args] = await oracle(
      true,
      tokenAddress,
      initRecord,
      tokenAddresses,
      hre
    );
    const oracleContract = await hre.ethers.getContractAt(
      oracleName,
      (
        await hre.deployments.get(oracleName)
      ).address
    );

    const [matches, abiEncoded] =
      await oracleContract.encodeAndCheckOracleParams(...args);

    if (!matches) {
      if (!(oracleContract.address in oracleActivationArgs)) {
        oracleActivationArgs[oracleContract.address] = {
          tokens: [],
          pegCurrencies: [],
          colRatios: [],
          data: [],
        };
      }

      // TODO: check col ratio is matching!

      const oracleActivationState =
        oracleActivationArgs[oracleContract.address];
      const colRatio = BigNumber.from(
        ((initRecord.colRatioPercent ?? 166) * 100).toString()
      );

      oracleActivationState.tokens.push(tokenAddress);
      oracleActivationState.pegCurrencies.push(args[1]);
      oracleActivationState.colRatios.push(colRatio);
      oracleActivationState.data.push(abiEncoded);
    }
  }

  for (const [tokenName, tokenAddress] of Object.entries(tokenAddresses)) {
    const initRecord = tokenInitRecords[tokenName];
    for (const [
      additionalTokenName,
      additionalOracle,
    ] of initRecord.additionalOracles ?? []) {
      // TODO handle intermediary tokens that may not show up in the main list?
      await processOracleCalls(
        additionalOracle,
        additionalTokenName,
        tokenAddresses[additionalTokenName]
      );
    }
    await processOracleCalls(initRecord.oracle, tokenName, tokenAddress);
  }

  return oracleActivationArgs;
}
